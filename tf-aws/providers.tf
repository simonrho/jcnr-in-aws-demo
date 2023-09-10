terraform {
  required_version = ">= 0.12"
}


provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "peer"
  region = var.peer_region
}


data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "demo1" {
  name = aws_eks_cluster.demo1.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.demo1.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.demo1.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.demo1.token
}

