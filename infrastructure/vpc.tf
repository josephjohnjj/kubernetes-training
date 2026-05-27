############################################
# AWS VPC and Networking Resources
############################################

# --------------------------------------------------------
# VPC (Virtual Private Cloud)
# --------------------------------------------------------
resource "aws_vpc" "main" {
  # The IPv4 CIDR block for the VPC (private IP range)
  cidr_block = "10.0.0.0/16" # Allows up to ~65,000 IPs in this private network

  # Enable DNS support so AWS assigns DNS hostnames to instances
  enable_dns_support = true

  # Enable DNS hostnames within the VPC (useful for EC2 instances)
  enable_dns_hostnames = true

  # Tags for identifying this VPC in AWS Console
  tags = {
    Name = "main-vpc"
  }
}

# --------------------------------------------------------
# Internet Gateway (Allows outbound/inbound internet traffic)
# --------------------------------------------------------
resource "aws_internet_gateway" "main" {
  # Attach this IGW to the VPC defined above
  vpc_id = aws_vpc.main.id

  # Tag to help identify the IGW in AWS Console
  tags = {
    Name = "main-gateway"
  }
}

# --------------------------------------------------------
# Public Subnet inside the VPC
# --------------------------------------------------------
resource "aws_subnet" "public" {
  # The VPC this subnet belongs to
  vpc_id = aws_vpc.main.id

  # CIDR block of this subnet - a smaller subnet inside the VPC range
  cidr_block = "10.0.1.0/24" # Provides ~250 usable IPs

  # Automatically assign a public IP address to instances launched in this subnet
  map_public_ip_on_launch = true


  availability_zone = var.target_az

  tags = {
    Name = "public-subnet"
  }
}

# --------------------------------------------------------
# Route Table for Public Subnet
# --------------------------------------------------------
resource "aws_route_table" "public" {
  # Associate this route table with the VPC
  vpc_id = aws_vpc.main.id

  # Define a route that sends all outbound traffic (0.0.0.0/0) to the internet gateway
  route {
    cidr_block = "0.0.0.0/0"                  # Matches all IPv4 addresses
    gateway_id = aws_internet_gateway.main.id # Send traffic to the IGW
  }

  tags = {
    Name = "public-route-table"
  }
}

# --------------------------------------------------------
# Associate the Route Table with the Public Subnet
# --------------------------------------------------------
resource "aws_route_table_association" "public_assoc" {
  # Which subnet to associate with this route table
  subnet_id = aws_subnet.public.id

  # The route table to associate with the subnet
  route_table_id = aws_route_table.public.id
}
