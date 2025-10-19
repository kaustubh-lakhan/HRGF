variable "aws_region" {
  description = "The AWS region where the resources will be created."
  type        = string
}

variable "cluster_name_prefix" {
  description = "The prefix for the EKS cluster name."
  type        = string
  default     = "devops-task-eks"
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "private_subnets_cidr" {
  description = "CIDR blocks for private subnets (3 AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "public_subnets_cidr" {
  description = "CIDR blocks for public subnets (3 AZs)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for Fluent Bit."
  type        = string
}

