# -----------------------------------------------------
# Security Group for SSH Access to EC2 Instances
# -----------------------------------------------------
resource "aws_security_group" "ssh_access" {
  # Name for the security group
  name = "allow_ssh_from_anywhere"

  # A human-readable description of what this SG does
  description = "Allow SSH inbound traffic"

  # Associate this security group with your main VPC
  vpc_id = aws_vpc.main.id

  # -------- Ingress Rules (Incoming Traffic) --------

  # Allow SSH (port 22) from any IPv4 address
  ingress {
    description = "SSH from anywhere (IPv4)"
    from_port   = 22            # Start of port range
    to_port     = 22            # End of port range (just port 22)
    protocol    = "tcp"         # SSH uses TCP
    cidr_blocks = ["0.0.0.0/0"] # Allow from any public IPv4 address
  }

  # Allow SSH (port 22) from any IPv6 address
  ingress {
    description      = "SSH from anywhere (IPv6)"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"] # Allow from any public IPv6 address
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
    Name = "ssh-sg" # Tag shown in AWS for this SG
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
    description = "Prometheus port 9090"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana port 3000"
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
    Name = "monitoring-sg"
  }
}


