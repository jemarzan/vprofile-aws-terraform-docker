# ---------------------------------------------------------------------------
# Data Sources – resolve default VPC / subnet when not explicitly provided
# ---------------------------------------------------------------------------

data "aws_vpc" "target" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : null
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.target.id]
  }

  # Only subnets that auto-assign public IPs
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }

  # Exclude us-east-1e — c7i-flex is not supported there
  filter {
    name   = "availabilityZone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

# ---------------------------------------------------------------------------
# Security Group – vprofile Docker host
# ---------------------------------------------------------------------------

resource "aws_security_group" "vprofile_docker" {
  name        = "${var.project_name}-${var.environment}-docker-sg"
  description = "Security group for vprofile Docker host"
  vpc_id      = data.aws_vpc.target.id

  # ------------------------------------------------------------------
  # Inbound
  # ------------------------------------------------------------------

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP – Nginx reverse proxy (vproweb container, port 80)
  ingress {
    description = "HTTP - vproweb Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  # Tomcat – vproapp direct access (optional; useful during development)
  ingress {
    description = "Tomcat - vproapp direct"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  # ------------------------------------------------------------------
  # Outbound (unrestricted – instance needs to pull images, run updates)
  # ------------------------------------------------------------------
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-docker-sg"
  }
}
