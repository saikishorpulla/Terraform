provider "aws" {
  region = var.region
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  # pin a stable module version (choose one supported by your providers)
  version = ">= 18.0, < 22.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"          # change if you prefer another supported k8s version

  # Let module create a VPC for you (simple)
  create_vpc = true

  # managed node group(s)
  node_groups = {
    default = {
      desired_capacity = var.node_desired_capacity
      min_capacity     = 1
      max_capacity     = 2
      instance_types   = [var.node_instance_type]
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "jenkins-eks"
  }
}
