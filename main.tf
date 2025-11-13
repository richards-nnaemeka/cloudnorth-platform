# main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# Data source for availability zones in Ohio
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to find available PostgreSQL versions
data "aws_rds_engine_version" "postgresql" {
  engine  = "postgres"
}

# VPC for CloudNorth
resource "aws_vpc" "cloudnorth_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cloudnorth-vpc-ohio"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "cloudnorth_igw" {
  vpc_id = aws_vpc.cloudnorth_vpc.id

  tags = {
    Name = "cloudnorth-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.cloudnorth_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "cloudnorth-public-subnet-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudnorth_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudnorth_igw.id
  }

  tags = {
    Name = "cloudnorth-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_rta" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "cloudnorth-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.cloudnorth_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "cloudnorth-ec2-sg"
  }
}

# EC2 Instances - Frontend
resource "aws_instance" "frontend" {
  ami                    = "ami-0a695f0d95cefc163" # Amazon Linux 2023 in Ohio
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name != "" ? var.key_name : null  # Only use if provided

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              EOF

  tags = {
    Name = "cloudnorth-frontend"
  }
}

# EC2 Instances - Backend
resource "aws_instance" "backend" {
  ami                    = "ami-0a695f0d95cefc163" # Amazon Linux 2023 in Ohio
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnets[1].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name != "" ? var.key_name : null  # Only use if provided

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              EOF

  tags = {
    Name = "cloudnorth-backend"
  }
}

# S3 Bucket for static assets
resource "aws_s3_bucket" "static_assets" {
  bucket = "cloudnorth-static-assets-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "cloudnorth-static-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# DB Subnet Group
resource "aws_db_subnet_group" "cloudnorth_db_subnet" {
  name       = "cloudnorth-db-subnet-group"
  subnet_ids = aws_subnet.public_subnets[*].id

  tags = {
    Name = "cloudnorth-db-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "cloudnorth-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.cloudnorth_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudnorth-rds-sg"
  }
}

# RDS Database - SINGLE DEFINITION (remove duplicates)
resource "aws_db_instance" "cloudnorth_db" {
  identifier              = "cloudnorth-db"
  engine                  = data.aws_rds_engine_version.postgresql.engine
  engine_version          = data.aws_rds_engine_version.postgresql.version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "cloudnorth"
  username                = var.db_username
  password                = var.db_password
  port                    = 5432
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.cloudnorth_db_subnet.name
  skip_final_snapshot     = true
  publicly_accessible     = true

  tags = {
    Name = "cloudnorth-postgres-db"
  }
}
