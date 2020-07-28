# VPC

resource "aws_vpc" "test_vpc" {
  cidr_block           = var.cidr_range
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_classiclink   = false

  tags = {
    Name        = var.vpc_name
    Terraformed = true
    Project     = var.project
  }
}

locals {
  zones = "${split(",", lookup(var.azs, data.aws_region.current.name))}"
}

resource "aws_internet_gateway" "test_ig" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name    = "${var.vpc_name} igw"
    Project = var.project
    env     = var.env_name
  }
}

# Public Subnet

resource "aws_subnet" "test_public_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  count                   = length(local.zones)
  cidr_block              = element(concat(var.public_subnets, list("")), count.index)
  availability_zone       = element(local.zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${element(local.zones, count.index)}-public"
    Terraformed = true
    project     = var.project
    env         = var.env_name
  }
}

resource "aws_route_table" "test_pub_route" {
  vpc_id = aws_vpc.test_vpc.id
  count  = length(local.zones)

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test_ig.id
  }

  tags = {
    Name        = "IGW ${var.project}-${element(local.zones, count.index)}-public"
    Terraformed = true
    project     = var.project
    env         = var.env_name
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = element(aws_subnet.test_public_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.test_pub_route.*.id, count.index)
  count          = length(local.zones)
}

resource "aws_eip" "test_eip" {
  count = length(local.zones)
  vpc   = true

  tags = {
    project = var.project
  }
}

resource "aws_nat_gateway" "test_private_gate" {
  count         = length(local.zones)
  allocation_id = element(aws_eip.test_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.test_public_subnet.*.id, count.index)

  depends_on = [aws_internet_gateway.test_ig]

  tags = {
    Name        = "${var.project}-ngw-${element(local.zones, count.index)}-public"
    Terraformed = true
    project     = var.project
  }
}
