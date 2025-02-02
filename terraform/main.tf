locals {
  tags = {
    Departament  = "Infraestructure and Operations",
    Organization = "test-w9",
    Project      = "Test-W9"
  }
}

variable "cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR for VPC"
}

variable "project" {
  type        = string
  default     = "test-w9"
  description = "Name of project"
}

variable "all_ipv4" {
  type        = string
  default     = "0.0.0.0/0"
  description = "All IPV4"
}

resource "aws_vpc" "test_w9_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.tags,
    {
      Name = "${var.project}-vpc"
    }
  )
}

data "aws_region" "current" {}

resource "aws_subnet" "test_w9_subnet_public_1a" {
  vpc_id            = aws_vpc.test_w9_vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone = "${data.aws_region.current.name}a"

  tags = merge(
    local.tags,
    {
      Name = "${var.project}-subnet-pub-1a",
    }
  )
}

resource "aws_internet_gateway" "test_w9_igw" {
  vpc_id = aws_vpc.test_w9_vpc.id

  tags = merge(
    local.tags,
    {
      Name = "${var.project}-igw"
    }
  )
}

resource "aws_route_table" "test_w9_pub_rtb" {
  vpc_id = aws_vpc.test_w9_vpc.id

  route {
    cidr_block = var.all_ipv4
    gateway_id = aws_internet_gateway.test_w9_igw.id
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.project}-pub-rtb"
    }
  )
}

resource "aws_route_table_association" "test_w9_rtb_assoc_1a" {
  subnet_id      = aws_subnet.test_w9_subnet_public_1a.id
  route_table_id = aws_route_table.test_w9_pub_rtb.id
}

resource "aws_security_group" "w9" {
  name        = "w9-sg"
  description = "Ports necessary for the cluster w9"
  vpc_id      = aws_vpc.test_w9_vpc.id

  tags = merge(
    local.tags,
    {
      Name = "${var.project}-w9-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "w9_all_traffic_ingress" {
  security_group_id = aws_security_group.w9.id

  ip_protocol = -1
  cidr_ipv4   = var.all_ipv4

  tags = {
    Name = "all-traffic"
  }
}

resource "aws_vpc_security_group_egress_rule" "w9_all_traffic" {
  security_group_id = aws_security_group.w9.id

  ip_protocol = -1
  cidr_ipv4   = var.all_ipv4

  tags = {
    Name = "all-traffic"
  }
}

resource "aws_instance" "w9_ec2" {
  ami                     = "ami-04b4f1a9cf54c11d0"
  instance_type           = "t3a.small"
  key_name                = "infra-joaopedro"
  subnet_id               = aws_subnet.test_w9_subnet_public_1a.id
  disable_api_termination = true
  monitoring              = false
  private_ip              = "10.0.1.10"
  vpc_security_group_ids  = [aws_security_group.w9.id]
  ebs_optimized           = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 70
    delete_on_termination = false

    tags = merge(
      local.tags,
      {
        Name = "${var.project}-w9-ec2-vol"
      }
    )
  }
  tags = merge(
    local.tags,
    {
      Name = "${var.project}-w9-ec2"
    }
  )

  user_data = <<-EOF
  #!/bin/bash
  apt-get update
  apt-get upgrade -y
  apt install docker.io vim htop fish -y
  usermod -aG docker ubuntu
  chsh -s /usr/bin/fish
  EOF
}

resource "aws_eip" "w9_ec2_eip" {
  instance                  = aws_instance.w9_ec2.id
  domain                    = "vpc"
  associate_with_private_ip = "10.0.1.10"

  tags = merge(
    local.tags,
    {
      Name = "${var.project}-w9-ec2-eip"
    }
  )
}
