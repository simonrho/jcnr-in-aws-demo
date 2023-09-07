# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

# The Amazon EBS CSI driver isn't installed when you first create a cluster. To use the driver, you must add it as an Amazon EKS add-on or as a self-managed add-on.
# https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html


resource "aws_iam_role" "demo1-cluster" {
  name = "${var.cluster_name}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo1-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.demo1-cluster.name
}

resource "aws_iam_role_policy_attachment" "demo1-cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.demo1-cluster.name
}



resource "aws_eks_cluster" "demo1" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.demo1-cluster.arn

  vpc_config {
    subnet_ids = [for s in aws_subnet.demo1 : s.id]
  }

  tags = {
    Name = var.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo1-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.demo1-cluster-AmazonEKSVPCResourceController,
  ]
}


resource "null_resource" "update_kubeconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}"
  }

  depends_on = [
    aws_eks_cluster.demo1
  ]
}
