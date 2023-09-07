# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#

resource "aws_iam_role" "demo1-node" {
  name = "${var.cluster_name}-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo1-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.demo1-node.name
}

resource "aws_iam_role_policy_attachment" "demo1-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.demo1-node.name
}

resource "aws_iam_role_policy_attachment" "demo1-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.demo1-node.name
}

resource "aws_iam_role_policy_attachment" "demo1-cluster-AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.demo1-node.name
}



resource "aws_eks_node_group" "demo1" {
  cluster_name    = aws_eks_cluster.demo1.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.demo1-node.arn
  subnet_ids      = [for s in aws_subnet.demo1 : s.id]
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key = aws_key_pair.my_public_ssh_key.key_name
  }

  tags = {
    Name = "${var.cluster_name}-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo1-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo1-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo1-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

