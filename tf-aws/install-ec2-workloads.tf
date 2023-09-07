
# Add secondary CIDR block
resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  vpc_id     = aws_vpc.demo1.id
  cidr_block = var.vpc_secondary_cidr_block
  depends_on = [
    aws_vpc.demo1
  ]
}


resource "aws_subnet" "demo1_secondary" {
  count = length(var.vpc_secondary_subnets)

  availability_zone       = data.aws_instance.eks_node.availability_zone
  cidr_block              = var.vpc_secondary_subnets[count.index].cidr
  vpc_id                  = aws_vpc.demo1.id
  map_public_ip_on_launch = true

  depends_on = [
    aws_route_table.demo1,
    aws_vpc.demo1,
    aws_vpc_ipv4_cidr_block_association.secondary_cidr
  ]

  tags = {
    "Name"                                      = "${var.cluster_name}-${var.vpc_secondary_subnets[count.index].name}-secondary",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}



# Route Table Associations for secondary CIDR
resource "aws_route_table_association" "demo1_secondary" {
  count = length(aws_subnet.demo1_secondary)

  subnet_id      = aws_subnet.demo1_secondary[count.index].id
  route_table_id = aws_route_table.demo1.id

  depends_on = [
    aws_subnet.demo1_secondary,
    aws_route_table.demo1,
    aws_vpc.demo1
  ]
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }

  owners = ["amazon"]
}


# Create an EC2 instance for each vpc_secondary_subnets entry
resource "aws_instance" "ce_instance" {
  count = length(var.vpc_secondary_subnets)

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_public_ssh_key.key_name

  subnet_id = aws_subnet.demo1_secondary[count.index].id

  vpc_security_group_ids = [aws_security_group.ce_sq.id]
  availability_zone      = data.aws_instance.eks_node.availability_zone

  private_ip = cidrhost(tolist(aws_subnet.demo1_secondary.*.cidr_block)[count.index], 200)

  user_data = <<-EOF
              #!/bin/bash
              prefix=${var.vpc_secondary_subnets[count.index].peer_cidr}
              gateway=${cidrhost(tolist(aws_subnet.demo1_secondary.*.cidr_block)[count.index], 100)}
              ip route add $prefix via $gateway
              hostnamectl set-hostname "${var.vpc_secondary_subnets[count.index].hostname}"
              EOF


  tags = {
    Name = "${var.cluster_name}-ce-instance-${count.index}"
  }
}

# Create a Security Group for ce interface
resource "aws_security_group" "ce_sq" {
  vpc_id      = aws_vpc.demo1.id
  name        = "example"
  description = "Example security group"

  # SSH Ingress
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP Ingress (ping)
  ingress {
    from_port   = -1 # ICMP doesn't have ports, use -1
    to_port     = -1 # ICMP doesn't have ports, use -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# JCNR additional interfaces (eth3, eth4, ...) to connect EC2 instances as CE workloads
resource "aws_network_interface" "jcnr_ce_interface" {
  count = length(aws_subnet.demo1_secondary)

  subnet_id         = tolist(aws_subnet.demo1_secondary.*.id)[count.index]
  security_groups   = [aws_security_group.jcnr_ce_sg.id]
  private_ips       = [cidrhost(tolist(aws_subnet.demo1_secondary.*.cidr_block)[count.index], 100)]
  source_dest_check = false

  tags = {
    "node.k8s.amazonaws.com/no_manage" = "true"
  }
}

resource "aws_network_interface_attachment" "jcnr_ce_interface_attachment" {
  count = length(aws_network_interface.jcnr_ce_interface)

  instance_id          = data.aws_instance.eks_node.instance_id
  network_interface_id = element(aws_network_interface.jcnr_ce_interface.*.id, count.index)
  device_index         = 3 + count.index
}

resource "aws_security_group" "jcnr_ce_sg" {
  name        = "jcnr-ce-sg"
  description = "jcnr-ce-sg"
  vpc_id      = aws_vpc.demo1.id
}

resource "aws_security_group_rule" "ingress_all_traffic_jcnr_ce_sg" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jcnr_ce_sg.id
}

resource "aws_security_group_rule" "egress_all_traffic_jcnr_ce_sg" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jcnr_ce_sg.id
}

