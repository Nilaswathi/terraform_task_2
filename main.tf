
# ============================================
# Terraform: Multi Region EC2 + Nginx
# ============================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# ============================================
# Provider 1 - Mumbai
# ============================================

provider "aws" {
  alias  = "mumbai"
  region = "ap-south-1"
}

# ============================================
# Provider 2 - Virginia
# ============================================

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

# ============================================
# Mumbai VPC and Subnet
# ============================================

data "aws_vpc" "mumbai" {
  provider = aws.mumbai
  default  = true
}

data "aws_subnets" "mumbai" {
  provider = aws.mumbai

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.mumbai.id]
  }
}

# ============================================
# Virginia VPC and Subnet
# ============================================

data "aws_vpc" "virginia" {
  provider = aws.virginia
  default  = true
}

data "aws_subnets" "virginia" {
  provider = aws.virginia

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.virginia.id]
  }
}

# ============================================
# Amazon Linux AMI - Mumbai
# ============================================

data "aws_ami" "mumbai" {
  provider    = aws.mumbai
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ============================================
# Amazon Linux AMI - Virginia
# ============================================

data "aws_ami" "virginia" {
  provider    = aws.virginia
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ============================================
# Security Group - Mumbai
# ============================================

resource "aws_security_group" "mumbai_sg" {
  provider    = aws.mumbai
  name        = "terraform-mumbai-nginx-sg"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.mumbai.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Mumbai-Nginx-SG"
  }
}

# ============================================
# Security Group - Virginia
# ============================================

resource "aws_security_group" "virginia_sg" {
  provider    = aws.virginia
  name        = "terraform-virginia-nginx-sg"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.virginia.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Virginia-Nginx-SG"
  }
}

# ============================================
# EC2 - Mumbai with Nginx
# ============================================

resource "aws_instance" "mumbai_ec2" {
  provider      = aws.mumbai
  ami           = data.aws_ami.mumbai.id
  instance_type = "t3.micro"

  subnet_id                   = data.aws_subnets.mumbai.ids[0]
  vpc_security_group_ids      = [aws_security_group.mumbai_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install nginx -y
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Nginx Server - Mumbai Region</h1>" > /usr/share/nginx/html/index.html
  EOF

  user_data_replace_on_change = true

  tags = {
    Name        = "Mumbai-Nginx-EC2"
    Environment = "Dev"
  }
}

# ============================================
# EC2 - Virginia with Nginx
# ============================================

resource "aws_instance" "virginia_ec2" {
  provider      = aws.virginia
  ami           = data.aws_ami.virginia.id
  instance_type = "t3.micro"

  subnet_id                   = data.aws_subnets.virginia.ids[0]
  vpc_security_group_ids      = [aws_security_group.virginia_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install nginx -y
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Nginx Server - Virginia Region</h1>" > /usr/share/nginx/html/index.html
  EOF

  user_data_replace_on_change = true

  tags = {
    Name        = "Virginia-Nginx-EC2"
    Environment = "Dev"
  }
}

# ============================================
# Outputs
# ============================================

output "mumbai_instance_id" {
  value = aws_instance.mumbai_ec2.id
}

output "mumbai_public_ip" {
  value = aws_instance.mumbai_ec2.public_ip
}

output "mumbai_nginx_url" {
  value = "http://${aws_instance.mumbai_ec2.public_ip}"
}

output "virginia_instance_id" {
  value = aws_instance.virginia_ec2.id
}

output "virginia_public_ip" {
  value = aws_instance.virginia_ec2.public_ip
}

output "virginia_nginx_url" {
  value = "http://${aws_instance.virginia_ec2.public_ip}"
}

