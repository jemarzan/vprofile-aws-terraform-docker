variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "vprofile"
}

variable "instance_type" {
  description = "EC2 instance type for the Docker host"
  type        = string
  default     = "c7i-flex.large"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS (update per region)"
  type        = string
  default     = "ami-0fc5d935ebf8bc3bc" # Ubuntu 22.04 LTS us-east-1 (update as needed)
}

variable "key_name" {
  description = "Name of the EC2 Key Pair to create and use"
  type        = string
  default     = "vprofile-keypair"
}


variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0" # Restrict to your IP in production: e.g. "203.0.113.10/32"
}

variable "allowed_web_cidr" {
  description = "CIDR block allowed to access the web (port 80)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_id" {
  description = "VPC ID to deploy into (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID to deploy into (leave empty to auto-select)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}
