data "aws_instances" "selected_instances" {
  instance_tags = {
    "eks:nodegroup-name" = aws_eks_node_group.demo1.node_group_name
  }
  depends_on = [
    aws_eks_node_group.demo1
  ]
}

locals {
  first_instance_id = data.aws_instances.selected_instances.ids[0]
}

data "aws_instance" "eks_node" {
  instance_id = local.first_instance_id
}


resource "aws_subnet" "vpc_peering_subnet" {
  vpc_id            = aws_vpc.demo1.id
  cidr_block        = var.peering_subnet
  availability_zone = data.aws_instance.eks_node.availability_zone

  tags = {
    Name = "vpc-peering-subnet1"
  }
}

resource "aws_security_group" "peering_sg" {
  name        = "peering-sq"
  description = "peering-sq"
  vpc_id      = aws_vpc.demo1.id
}

resource "aws_security_group_rule" "ingress_all_traffic" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.peering_sg.id
}

resource "aws_security_group_rule" "egress_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.peering_sg.id
}


resource "aws_network_interface" "peering_interface" {
  subnet_id       = aws_subnet.vpc_peering_subnet.id
  security_groups = [aws_security_group.peering_sg.id]
  private_ips     = [cidrhost(var.peering_subnet, 100)]
  source_dest_check = false

  tags = {
    "node.k8s.amazonaws.com/no_manage" = "true"
  }
}

resource "aws_network_interface_attachment" "peering_interface_attachment" {
  instance_id          = local.first_instance_id
  network_interface_id = aws_network_interface.peering_interface.id
  device_index         = 2
}

resource "aws_route_table_association" "vpc_peering_subnet_association" {
  subnet_id      = aws_subnet.vpc_peering_subnet.id
  route_table_id = aws_route_table.demo1.id
}


