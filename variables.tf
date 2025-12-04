variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "demo-eks-cluster"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_desired_capacity" {
  type    = number
  default = 1
}
