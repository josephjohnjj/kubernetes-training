# -----------------------------------------------------
# Talos API access. There is deliberately no SSH security group.
# -----------------------------------------------------
resource "aws_security_group" "talos_api" {
  # Name for the security group
  name = "talos-api-access"

  # A human-readable description of what this SG does
  description = "Allow authenticated Talos API access from administrator networks"

  # Associate this security group with your main VPC
  vpc_id = aws_vpc.main.id

  # -------- Ingress Rules (Incoming Traffic) --------

  dynamic "ingress" {
    for_each = length(var.talos_api_allowed_cidrs) == 0 ? [] : [1]
    content {
      description = "Talos API from approved administrator networks"
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = var.talos_api_allowed_cidrs
    }
  }

  # -------- Egress Rules (Outgoing Traffic) --------

  # Allow all outbound traffic to the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means "all protocols"
    cidr_blocks = ["0.0.0.0/0"] # Send to any IPv4 address
  }

  # Tags help identify this resource in the AWS Console
  tags = {
    Name = "talos-api-sg"
  }
}

resource "aws_security_group" "kubernetes_api" {
  name        = "kubernetes-api-access"
  description = "Allow direct Kubernetes API access on every control-plane DNS target"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = length(var.talos_api_allowed_cidrs) == 0 ? [] : [1]
    content {
      description = "Kubernetes API from approved administrator networks"
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = var.talos_api_allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubernetes-api-sg"
  }
}

resource "aws_security_group" "ingress_web" {
  name        = "talos-ingress-web"
  description = "Allow public HTTP and HTTPS directly to ingress-nginx on Talos ingress workers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Public HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "talos-ingress-web-sg"
  }
}

# -----------------------------------------------------
# Security Group for EFS Access
# -----------------------------------------------------
resource "aws_security_group" "efs_sg" {
  # Name for this SG
  name = "efs-access"

  # Description for humans
  description = "Allow NFS access to EFS"

  # Associate with the same VPC
  vpc_id = aws_vpc.main.id

  # -------- Ingress Rule for NFS Access --------

  # Allow inbound traffic on TCP port 2049 (used for NFS)
  ingress {
    description     = "NFS access from EC2 instances"
    from_port       = 2049 # NFS port
    to_port         = 2049
    protocol        = "tcp" # NFS uses TCP
    security_groups = [aws_security_group.internal.id]
    # 👆 This allows only EC2 instances in the 'internal' SG to connect
    # to EFS using NFS. It references the other SG directly.
  }

  # -------- Egress Rule --------

  # Allow all outbound traffic from EFS (for updates, metrics, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Any IPv4 destination
  }

  tags = {
    Name = "efs-sg"
  }
}


# -----------------------------------------------------
# Security Group for Internal Node Communication
# -----------------------------------------------------
resource "aws_security_group" "internal" {
  name        = "internal-communication"
  description = "Allow internal traffic between EC2 nodes"
  vpc_id      = aws_vpc.main.id

  # Allow internal communication on all ports (fine-tuned later if needed)
  ingress {
    description = "Allow all traffic from within the SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "internal-sg"
  }
}


resource "aws_security_group" "monitoring" {
  name        = "monitoring-access"
  description = "Allow inbound Prometheus and Grafana ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP access through HAProxy and Ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access through HAProxy and Ingress"
    from_port   = 443
    to_port     = 443
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
    Name = "monitoring-sg"
  }
}
