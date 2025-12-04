variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "demo-eks-cluster"
}

variable "kubernetes_version" {
  type    = string
  default = "1.28"
}

variable "node_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "node_desired_capacity" {
  type    = number
  default = 2
}

# optional: state bucket name when using S3 backend
variable "tfstate_bucket" {
  type    = string
  default = ""
}
