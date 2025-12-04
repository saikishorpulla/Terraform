provider "aws" {
  region = var.region
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"        # explicit working version

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  create_vpc = true

  node_groups = {
    default = {
      desired_capacity = var.node_desired_capacity
      min_capacity     = 1
      max_capacity     = 2
      instance_types   = [var.node_instance_type]
    }
  }

  tags = {
    Environment = "dev"
    Project     = "jenkins-eks"
  }
}
