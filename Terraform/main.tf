# --- EKS Cluster & VPC Infrastructure ---

# --- Naming and Locals ---

resource "random_string" "suffix" {
  # Used to ensure unique names across environments/runs
  length  = 4
  special = false
  upper   = false
  numeric = true
}

locals {
  cluster_name = "${var.cluster_name_prefix}-${random_string.suffix.result}"
}

# --- AWS Resources ---

# Using AWS standard naming for EKS logs and retention
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 90
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC Module ---

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "${local.cluster_name}-vpc"
  cidr    = var.vpc_cidr_block
  azs     = data.aws_availability_zones.available.names

  private_subnets = var.private_subnets_cidr
  public_subnets  = var.public_subnets_cidr

  enable_nat_gateway = true
  single_nat_gateway = false # Creates a NAT Gateway per AZ for High Availability

  # Required tags for EKS Load Balancer controller to discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                       = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"              = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

# --- EKS Cluster Module ---

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  
  # Fargate only uses private subnets
  subnet_ids = module.vpc.private_subnets 

  # Secure configuration: API endpoint is private
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  enable_irsa = true # Required for Pod Identity
  
  # Enable all logs for audit and monitoring purposes
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Tag required for tools like Karpenter/ExternalDNS discovery (CRITICAL)
  tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  # Fargate Profiles for serverless compute
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        { namespace = "kube-system" }, 
        { namespace = "monitoring" },
        { namespace = "logging" }
      ]
    }
    application = {
      name = "application"
      selectors = [
        { namespace = "app" } 
      ]
    }
  }

  # EKS Managed Add-ons (ESSENTIAL)
  cluster_addons = {
    coredns            = {}
    kube-proxy         = {}
    vpc-cni            = { resolve_conflicts = "OVERWRITE" }
    aws-ebs-csi-driver = {}
  }
}

# --- Provider Configuration (CRITICAL FIXES) ---

# Data source required for providers to fetch authentication token
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # Recommended: Uses AWS CLI for auto-refreshing token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name] 
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    # CRITICAL FIX: Helm must also use 'exec' for long-lived credentials
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name] 
    }
  }
}

# --- Kubernetes Add-ons Deployment ---

# ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/helm-charts"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      server = {
        replicas = 3
        service = {
          type = "LoadBalancer"
          # Internet-facing NLB for CI/CD pipeline access to the ArgoCD API
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
            # Reference VPC module output directly
            "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", module.vpc.public_subnets)
          }
        }
      }
      # Removed nodeSelector/tolerations for Fargate compatibility
    })
  ]
}

data "kubernetes_service" "argocd_server" {
 depends_on = [helm_release.argocd]
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
}


# AWS Secrets Manager CSI Driver
module "secrets_manager_csi_irsa" {
  source                          = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                         = "~> 5.0"
  role_name_prefix                = "sm-csi-driver"
  attach_external_secrets_policy  = true
  # Reference EKS module OIDC ARN output
  oidc_providers = { main = { provider_arn = module.eks.oidc_provider_arn, namespace_service_accounts = ["kube-system:aws-secrets-manager-csi-driver"] } }
}

resource "helm_release" "aws_secrets_manager_csi_driver" {
  name             = "aws-secrets-manager-csi-driver"
  repository       = "https://aws.github.io/secrets-manager-csi-driver-helm"
  chart            = "secrets-manager-csi-driver"
  namespace        = "kube-system"

  set {
    name  = "serviceAccount.name"
    value = "aws-secrets-manager-csi-driver"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.secrets_manager_csi_irsa.iam_role_arn
  }
}


# Fluent Bit
resource "aws_iam_policy" "fluentbit_cw" {
  name = "${local.cluster_name}-fluentbit-policy" # Use local.cluster_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "*" }
    ]
 })
}

module "fluentbit_irsa" {
  source             = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version            = "~> 5.0"
  role_name_prefix   = "fluentbit"
  role_policy_arns = {
    fluentbit_policy = aws_iam_policy.fluentbit_cw.arn
  }
  # Reference EKS module OIDC ARN output
  oidc_providers = { main = { provider_arn = module.eks.oidc_provider_arn, namespace_service_accounts = ["logging:fluent-bit"] } }
}

resource "helm_release" "fluentbit" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  namespace        = "logging"
  create_namespace = true

  values = [
    templatefile("${path.module}/addons_modules/fluentbit-values.yaml", {
      region_name = var.aws_region,
      # Reference the created CloudWatch log group name
      log_group   = aws_cloudwatch_log_group.eks.name 
    })
  ]
  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.fluentbit_irsa.iam_role_arn
  }
}

#---

# Karpenter 
module "karpenter_irsa" {
  source                             = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                            = "~> 5.0"
  role_name_prefix                   = "karpenter"
  attach_karpenter_controller_policy = true
  # Reference EKS module OIDC ARN output
  oidc_providers = { main = { provider_arn = module.eks.oidc_provider_arn, namespace_service_accounts = ["karpenter:karpenter"] } }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter/karpenter"
  chart            = "karpenter"
  version          = "v0.34.0"
  namespace        = "karpenter"
  create_namespace = true

  set {
    name  = "settings.clusterName"
    value = local.cluster_name # Use local.cluster_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/sts-regional-endpoints"
    value = "true"
  }
  # Removed all tolerations for Fargate compatibility
}

# AWS Load Balancer Controller
module "aws_lbc_irsa" {
  source                                   = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                                  = "~> 5.0"
  role_name_prefix                         = "aws-lbc"
  attach_load_balancer_controller_policy   = true
  # Reference EKS module OIDC ARN output
  oidc_providers = { main = { provider_arn = module.eks.oidc_provider_arn, namespace_service_accounts = ["kube-system:aws-load-balancer-controller"] } }
}

resource "helm_release" "aws_lbc" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"

  set {
    name  = "clusterName"
    value = local.cluster_name # Use local.cluster_name
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_lbc_irsa.iam_role_arn
  }
  set {
    name  = "serviceAccount.create"
    value = "false" # Must be false since we create the SA via IRSA module indirectly
  }
  # Removed all tolerations for Fargate compatibility
}

#---

# Prometheus and Grafana
resource "helm_release" "monitoring" {
  name             = "prometheus-grafana"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  values = [
    templatefile("${path.module}/addons_modules/prometheus-values.yaml", { 
      # Reference VPC module output directly
      private_subnet_ids = join(",", module.vpc.private_subnets) 
    })
  ]
}

#---

# --- Outputs ---

output "cluster_name" {
  description = "The final, unique name of the EKS cluster."
  value       = local.cluster_name
}

output "argocd_nlb_hostname" {
  description = "Hostname for the ArgoCD Load Balancer"
  # Correct way to extract the LoadBalancer hostname from a Kubernetes Service data source
  value       = element(coalescelist(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress.*.hostname, [""]), 0)
} 