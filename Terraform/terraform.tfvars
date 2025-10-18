aws_region                = "us-east-1"
cluster_name_prefix       = "kaustubh"
cluster_version           = "1.29"
vpc_cidr_block            = "10.10.0.0/16"
private_subnets_cidr      = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
public_subnets_cidr       = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]
cloudwatch_log_group_name = "/eks/devops-task-cluster"