resource "aws_vpc" "demo1" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "Name"                                      = var.cluster_name,
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "demo1" {
  count = length(var.vpc_subnets)

  availability_zone       = data.aws_availability_zones.available.names[count.index % 2]
  cidr_block              = var.vpc_subnets[count.index].cidr
  vpc_id                  = aws_vpc.demo1.id
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "${var.cluster_name}-${var.vpc_subnets[count.index].name}",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}


resource "aws_internet_gateway" "demo1" {
  vpc_id = aws_vpc.demo1.id

  tags = {
    Name = "${var.cluster_name}-internet-gateway"
  }
}

resource "aws_route_table" "demo1" {
  vpc_id = aws_vpc.demo1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo1.id
  }

  tags = {
    "Name" = var.cluster_name,
  }
}

resource "aws_route_table_association" "demo1" {
  count = length(aws_subnet.demo1)


  subnet_id      = aws_subnet.demo1[count.index].id
  route_table_id = aws_route_table.demo1.id
}
