# CloudNorth E-commerce Platform

## Infrastructure as Code with Terraform

This project contains Terraform configurations for deploying the CloudNorth e-commerce platform on AWS.

### Architecture
- VPC with public subnets in us-east-2 (Ohio)
- 2 EC2 instances (frontend/backend) with Docker
- RDS PostgreSQL database
- S3 bucket for static assets
- Security groups and networking configuration

### Deployment
\\\ash
terraform init
terraform plan
terraform apply
\\\

### Outputs
- Database endpoint and connection details
- EC2 instance public IPs
- S3 bucket name
