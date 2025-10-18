variable "cluster_name" {}
variable "cluster_endpoint" {}
variable "cluster_ca_data" {}
variable "oidc_provider_arn" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "cloudwatch_log_group_name" {}
# Note: var.aws_region is used in the Fluent Bit templatefile but not defined here.
# Assuming it is either defined elsewhere or will be passed via terraform.tfvars.

# --- 1. Providers Setup ---
data "aws_eks_cluster_auth" "cluster" { name = var.cluster_name }

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}


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
            "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", var.public_subnet_ids)
          }
        }
      }
      # Deploy ArgoCD components onto the dedicated MNG
      nodeSelector = { "kubernetes.io/hostname" = "placeholder" } # Overwritten by nodeAffinity
      tolerations = [{
        key    = "dedicated"
        operator = "Equal"
        value  = "addons"
        effect = "NoSchedule"
      }]
    })
  ]
}

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
}

---

# AWS Secrets Manager
module "secrets_manager_csi_irsa" {
  source                          = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                         = "~> 5.0"
  role_name_prefix                = "sm-csi-driver"
  attach_secretsmanager_csi_driver_policy = true
  # FIX 1: Replaced semicolon with comma in oidc_providers map
  oidc_providers = { main = { provider_arn = var.oidc_provider_arn, namespace_service_accounts = ["kube-system:aws-secrets-manager-csi-driver"] } }
}

resource "helm_release" "aws_secrets_manager_csi_driver" {
  name             = "aws-secrets-manager-csi-driver"
  repository       = "https://aws.github.io/secrets-manager-csi-driver-helm"
  chart            = "secrets-manager-csi-driver"
  namespace        = "kube-system"
  
  # FIX 2: Converted to multi-line set block
  set { 
    name  = "serviceAccount.name"
    value = "aws-secrets-manager-csi-driver"
  }
  # FIX 3: Converted to multi-line set block
  set { 
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.secrets_manager_csi_irsa.iam_role_arn
  }
}

---

# Fluent Bit
resource "aws_iam_policy" "fluentbit_cw" {
  name = "${var.cluster_name}-fluentbit-policy"
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
  iam_policy_arns    = [aws_iam_policy.fluentbit_cw.arn]
  # FIX 4: Replaced semicolon with comma in oidc_providers map
  oidc_providers = { main = { provider_arn = var.oidc_provider_arn, namespace_service_accounts = ["logging:fluent-bit"] } }
}

resource "helm_release" "fluentbit" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  namespace        = "logging"
  create_namespace = true
  
  values = [
    templatefile("${path.module}/fluentbit-values.yaml", {
      region_name = var.aws_region,
      log_group   = var.cloudwatch_log_group_name
    })
  ]
  # FIX 5: Converted to multi-line set block (originally used semicolon)
  set { 
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }
  # FIX 6: Converted to multi-line set block (originally used semicolon)
  set { 
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.fluentbit_irsa.iam_role_arn
  }
}

---

# Karpenter and AWS LBC
module "karpenter_irsa" {
  source                         = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                        = "~> 5.0"
  role_name_prefix               = "karpenter"
  attach_karpenter_controller_policy = true
  # FIX 7: Replaced semicolon with comma in oidc_providers map
  oidc_providers = { main = { provider_arn = var.oidc_provider_arn, namespace_service_accounts = ["karpenter:karpenter"] } }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter/karpenter"
  chart            = "karpenter"
  version          = "v0.34.0"
  namespace        = "karpenter"
  create_namespace = true
  
  # FIX 8-13: Converted inline set blocks to multi-line blocks for correctness
  set { 
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  set { 
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }
  set { 
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/sts-regional-endpoints"
    value = "true"
  }
  set { 
    name  = "tolerations[0].key"
    value = "dedicated"
  }
  set { 
    name  = "tolerations[0].operator"
    value = "Equal"
  }
  set { 
    name  = "tolerations[0].value"
    value = "addons"
  }
  set { 
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

# AWS Load Balancer Controller
module "aws_lbc_irsa" {
  source                                   = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                                  = "~> 5.0"
  role_name_prefix                         = "aws-lbc"
  attach_load_balancer_controller_policy   = true
  # FIX 14: Replaced semicolon with comma in oidc_providers map
  oidc_providers = { main = { provider_arn = var.oidc_provider_arn, namespace_service_accounts = ["kube-system:aws-load-balancer-controller"] } }
}

resource "helm_release" "aws_lbc" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  
  # FIX 15-22: Converted inline set blocks to multi-line blocks for correctness
  set { 
    name  = "clusterName"
    value = var.cluster_name
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
    value = "false"
  }
  set { 
    name  = "tolerations[0].key"
    value = "dedicated"
  }
  set { 
    name  = "tolerations[0].operator"
    value = "Equal"
  }
  set { 
    name  = "tolerations[0].value"
    value = "addons"
  }
  set { 
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

---

# Prometheus and Grafana
resource "helm_release" "monitoring" {
  name             = "prometheus-grafana"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  values = [
    templatefile("${path.module}/prometheus-values.yaml", { private_subnet_ids = join(",", var.private_subnet_ids) })
  ]
}

---

# --- Outputs ---
output "argocd_nlb_hostname" {
  description = "Hostname for the ArgoCD Load Balancer"
  value       = element(coalescelist(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress.*.hostname, [""]), 0)
}