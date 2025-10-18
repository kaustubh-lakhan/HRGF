terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "kaustubh-terraform-project-state" 
    key            = "prod/eks/terraform.tfstate" 
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock" 
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


