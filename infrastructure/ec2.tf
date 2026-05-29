# ---------------------------
# Create an AWS Key Pair
# ---------------------------
resource "aws_key_pair" "hcp_key" {
  # The name of the key pair to create in AWS
  key_name = "terraform-user"

  # The public key file to register with AWS
  # This file should exist at keys/terraform-user.pub relative to the module path
  public_key = file("${path.module}/keys/terraform-user.pub")
}


# ---------------------------------------
# Launch an EC2 Instance as Controller Node
# ----------------------------------------
resource "aws_instance" "control_node" {

  # Number of instances to create
  count = var.control_node_count

  # The AMI ID for the EC2 instance.
  ami = var.controller_ami

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.control_instance_type

  # Use the key pair created above for SSH access.
  key_name = aws_key_pair.hcp_key.key_name

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id, # Security group for SSH access
    aws_security_group.internal.id,   # Internal communication within the VPC
    aws_security_group.efs_sg.id,     # EFS access for file systems
    aws_security_group.monitoring.id, # Monitoring access Prometheus, Grafana, etc.
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  # Add tags to the instance for identification and management.
  tags = {
    Name = "controllerNode-${count.index + 1}" # Name tag appears in the EC2 console
  }


  # Configure root volume
  root_block_device {
    volume_type           = "gp3" # Use gp3 for improved performance and cost control
    volume_size           = 200   # Size in GiB
    iops                  = 3000  # Provisioned IOPS (default for gp3 is 3000)
    encrypted             = false # Set to false for unencrypted volume (default is false)
    delete_on_termination = true  # Deletes the volume when the instance is terminated
  }

  # First additional disk 
  ebs_block_device {
    device_name           = "/dev/sdf" # Linux will map this to /dev/nvme1n1 on newer instances
    volume_type           = "gp3"
    volume_size           = 150 # Size in GiB
    iops                  = 3000
    encrypted             = false
    delete_on_termination = true
  }

}



# ---------------------------------------
# Launch an EC2 Instance as Login Node
# ----------------------------------------
resource "aws_instance" "login_node" {

  # Number of instances to create
  count = var.login_node_count

  # The AMI ID for the EC2 instance.
  ami = var.login_ami # Example AMI ID for Ubuntu 22.04 LTS

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.login_instance_type

  # Use the key pair created above for SSH access.
  key_name = aws_key_pair.hcp_key.key_name

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id, # Security group for SSH access
    aws_security_group.internal.id,   # Internal communication within the VPC
    aws_security_group.efs_sg.id,     # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  # Add tags to the instance for identification and management.
  tags = {
    Name = "loginNode-${count.index + 1}" # Name tag appears in the EC2 console
  }


  # Configure root volume
  root_block_device {
    volume_type           = "gp3" # Use gp3 for improved performance and cost control
    volume_size           = 100   # Size in GiB
    iops                  = 3000  # Provisioned IOPS (default for gp3 is 3000)
    encrypted             = false # Set to false for unencrypted volume (default is false)
    delete_on_termination = true  # Deletes the volume when the instance is terminated
  }

}

# ---------------------------------------
# Launch an EC2 Instance as Worker Node
# ----------------------------------------
resource "aws_instance" "worker_node_cpu" {

  # Number of instances to create
  count = var.worker_node_cpu_count

  # The AMI ID for the EC2 instance.
  ami = var.worker_cpu_ami # Example AMI ID for Ubuntu 22.04 LTS

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.worker_cpu_instance_type

  # Use the key pair created above for SSH access.
  key_name = aws_key_pair.hcp_key.key_name

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id, # Security group for SSH access
    aws_security_group.internal.id,   # Internal communication within the VPC
    aws_security_group.efs_sg.id,     # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  # Add tags to the instance for identification and management.
  tags = {
    Name = "workerNodeCpu-${count.index + 1}" # Name tag appears in the EC2 console
  }


  # Configure root volume
  root_block_device {
    volume_type           = "gp3" # Use gp3 for improved performance and cost control
    volume_size           = 200   #  Size in GiB
    iops                  = 3000  # Provisioned IOPS (default for gp3 is 3000)
    encrypted             = false # Set to false for unencrypted volume (default is false)
    delete_on_termination = true  # Deletes the volume when the instance is terminated
  }

  ebs_block_device {
    device_name           = "/dev/sdf" # Linux will map this to /dev/nvme1n1 on newer instances
    volume_type           = "gp3"
    volume_size           = 200 # Size in GiB
    iops                  = 3000
    encrypted             = false
    delete_on_termination = true
  }

}

# -----------------------------------------------
# Launch an EC2 Instance as Worker Node with GPU
# -----------------------------------------------
resource "aws_instance" "worker_node_gpu" {

  # Number of instances to create
  count = var.worker_node_gpu_count

  # The AMI ID for the EC2 instance.
  ami = var.worker_gpu_ami # Example AMI ID for Ubuntu 22.04 LTS

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.worker_gpu_instance_type

  # Use the key pair created above for SSH access.
  key_name = aws_key_pair.hcp_key.key_name

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id, # Security group for SSH access
    aws_security_group.internal.id,   # Internal communication within the VPC
    aws_security_group.efs_sg.id,     # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  # Add tags to the instance for identification and management.
  tags = {
    Name = "workerNodeCpu-${count.index + 1}" # Name tag appears in the EC2 console
  }


  # Configure root volume
  root_block_device {
    volume_type           = "gp3" # Use gp3 for improved performance and cost control
    volume_size           = 200   #  Size in GiB
    iops                  = 3000  # Provisioned IOPS (default for gp3 is 3000)
    encrypted             = false # Set to false for unencrypted volume (default is false)
    delete_on_termination = true  # Deletes the volume when the instance is terminated
  }

  ebs_block_device {
    device_name           = "/dev/sdf" # Linux will map this to /dev/nvme1n1 on newer instances
    volume_type           = "gp3"
    volume_size           = 200 # Size in GiB
    iops                  = 3000
    encrypted             = false
    delete_on_termination = true
  }


}


# ---------------------------------------
# Launch an EC2 Instance as Storage Node
# ----------------------------------------
resource "aws_instance" "storage_node" {

  # Number of instances to create
  count = var.storage_node_count

  # The AMI ID for the EC2 instance.
  ami = var.storage_ami

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.storage_instance_type

  # Use the key pair created above for SSH access.
  key_name = aws_key_pair.hcp_key.key_name

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id, # Security group for SSH access
    aws_security_group.internal.id,   # Internal communication within the VPC
    aws_security_group.efs_sg.id,     # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  # Add tags to the instance for identification and management.
  tags = {
    Name = "storageNode-${count.index + 1}" # Name tag appears in the EC2 console
  }


  # Configure root volume
  root_block_device {
    volume_type           = "gp3" # Use gp3 for improved performance and cost control
    volume_size           = 100   #  Size in GiB
    iops                  = 3000  # Provisioned IOPS (default for gp3 is 3000)
    encrypted             = false # Set to false for unencrypted volume (default is false)
    delete_on_termination = true  # Deletes the volume when the instance is terminated
  }

  # First additional disk
  ebs_block_device {
    device_name           = "/dev/sdf" # Linux will map this to /dev/nvme1n1 on newer instances
    volume_type           = "gp3"
    volume_size           = 200 # Size in GiB
    iops                  = 3000
    encrypted             = false
    delete_on_termination = true
  }

  # Second additional disk 
  ebs_block_device {
    device_name           = "/dev/sdg"
    volume_type           = "gp3"
    volume_size           = 200
    iops                  = 3000
    encrypted             = false
    delete_on_termination = true
  }

  # Third additional disk 
  ebs_block_device {
    device_name           = "/dev/sdh"
    volume_type           = "gp3"
    volume_size           = 200
    iops                  = 3000
    encrypted             = false
    delete_on_termination = true
  }

}
