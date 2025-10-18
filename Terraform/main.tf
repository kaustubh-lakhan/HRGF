
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

locals {
  cluster_name = "${var.cluster_name_prefix}-${random_string.suffix.result}"
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 90
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr_block
  azs                    = data.aws_availability_zones.available.names
  private_subnets        = var.private_subnets_cidr
  public_subnets         = var.public_subnets_cidr
  enable_nat_gateway     = true
  single_nat_gateway     = false
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets # Fargate only uses private subnets
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  cluster_encryption_enabled = true
  enable_irsa = true
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
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

  cluster_addons = {
    coredns            = {}
    kube-proxy         = {}
    vpc-cni            = { resolve_conflicts = "OVERWRITE" }
    aws-ebs-csi-driver = {}
  }
}


module "addons" {
  source = "./addons_modules"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca_data   = module.eks.cluster_certificate_authority_data
  oidc_provider_arn = module.eks.oidc_provider_arn
  aws_region        = var.aws_region
  # Networking
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  # Configuration
  cloudwatch_log_group_name = aws_cloudwatch_log_group.eks.name
}


output "cluster_name" {
  value = local.cluster_name
}


output "argocd_url" {
  description = "The public URL for the ArgoCD server (Wait for NLB creation)."
  value       = "http://${try(module.addons.argocd_nlb_hostname, "NLB not yet provisioned")}"
}