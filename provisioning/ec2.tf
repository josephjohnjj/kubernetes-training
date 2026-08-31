# ---------------------------
# Legacy SSH key creation has been removed. Talos nodes are managed exclusively
# through the authenticated Talos API.
# ---------------------------

# Talos hostname strategy
# -----------------------
# `talosctl gen config` emits multi-document YAML. Its HostnameConfig document
# defaults to `auto: stable`, which allows Talos or AWS metadata to produce
# names such as `ip-10-0-1-159`. Stable role-based names make Kubernetes and
# Rook-Ceph placement easier to understand and maintain.
#
# Do not add `machine.network.hostname` here. Talos 1.13 would see that and the
# generated HostnameConfig as two hostname sources and reject the configuration
# with "static hostname is already set". Each resource instead preserves the
# generated multi-document configuration and replaces only `auto: stable` with
# its per-instance `hostname:` value.
#
# The role configurations still share the original cluster PKI and tokens;
# only their hostnames differ. `user_data_replace_on_change` is intentional:
# Talos consumes AWS user data as its initial machine configuration, so an
# existing instance must be replaced when that configuration changes.

# ---------------------------------------
# Launch an EC2 Instance as Controller Node
# ----------------------------------------
resource "aws_instance" "control_node" {

  # Number of instances to create
  count = var.control_node_count

  # The AMI ID for the EC2 instance.
  ami = var.controller_ami
  # Talos 1.13 emits a separate HostnameConfig document with `auto: stable`.
  # Preserve the multi-document YAML and replace that setting with a unique
  # static hostname for this instance.
  user_data = replace(
    var.controlplane_machine_config,
    "auto: stable",
    "hostname: control${count.index + 1}"
  )
  user_data_replace_on_change = true

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.control_instance_type

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.talos_api.id,      # Talos API access
    aws_security_group.kubernetes_api.id, # Direct DNS-based Kubernetes API access
    aws_security_group.internal.id,       # Internal communication within the VPC
    aws_security_group.efs_sg.id,         # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Add tags to the instance for identification and management.
  tags = {
    Name = "control${count.index + 1}"
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

# The Kubernetes API endpoint is the stable Elastic IP allocated before Talos
# machine configuration generation. It is intentionally attached to control1;
# no AWS load balancer is used.
resource "aws_eip_association" "controlplane_api" {
  allocation_id = var.controlplane_api_eip_allocation_id
  instance_id   = aws_instance.control_node[0].id
}



# ---------------------------------------
# Launch a Talos ingress worker (temporarily retained as login_node in state)
# ----------------------------------------
resource "aws_instance" "login_node" {

  # Number of instances to create
  count = var.login_node_count

  # The AMI ID for the EC2 instance.
  ami = var.login_ami

  # Name ingress workers ingress1, ingress2, ... instead of using an AWS
  # private-DNS-derived Kubernetes node name.
  user_data = replace(
    var.ingress_machine_config,
    "auto: stable",
    "hostname: ingress${count.index + 1}"
  )
  user_data_replace_on_change = true

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.login_instance_type

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.talos_api.id, # Talos API access
    aws_security_group.ingress_web.id,
    aws_security_group.internal.id, # Internal communication within the VPC
    aws_security_group.efs_sg.id,   # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Add tags to the instance for identification and management.
  tags = {
    Name = "ingress${count.index + 1}"
    Role = "ingress"
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

resource "aws_eip" "ingress" {
  count    = var.login_node_count
  domain   = "vpc"
  instance = aws_instance.login_node[count.index].id

  tags = {
    Name = "ingress${count.index + 1}-eip"
  }
}

# ---------------------------------------
# Launch an EC2 Instance as Worker Node
# ----------------------------------------
resource "aws_instance" "worker_node_cpu" {

  # Number of instances to create
  count = var.worker_node_cpu_count

  # The AMI ID for the EC2 instance.
  ami = var.worker_cpu_ami

  # CPU workers occupy the first worker hostname sequence: worker1,
  # worker2, and so on.
  user_data = replace(
    var.worker_machine_config,
    "auto: stable",
    "hostname: worker${count.index + 1}"
  )
  user_data_replace_on_change = true

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.worker_cpu_instance_type

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.talos_api.id, # Talos API access
    aws_security_group.internal.id,  # Internal communication within the VPC
    aws_security_group.efs_sg.id,    # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Add tags to the instance for identification and management.
  tags = {
    Name = "worker${count.index + 1}"
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
  ami = var.worker_gpu_ami

  # Continue after the CPU-worker count so CPU and GPU resources cannot create
  # duplicate node names. With two CPU workers, GPU nodes start at worker3.
  user_data = replace(
    var.worker_machine_config,
    "auto: stable",
    "hostname: worker${var.worker_node_cpu_count + count.index + 1}"
  )
  user_data_replace_on_change = true

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.worker_gpu_instance_type

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.talos_api.id, # Talos API access
    aws_security_group.internal.id,  # Internal communication within the VPC
    aws_security_group.efs_sg.id,    # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Add tags to the instance for identification and management.
  tags = {
    Name = "worker${var.worker_node_cpu_count + count.index + 1}"
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

  # Storage machines use the shared worker Talos role and credentials, but
  # receive storage1, storage2, ... names for clear Rook-Ceph placement.
  user_data = replace(
    var.worker_machine_config,
    "auto: stable",
    "hostname: storage${count.index + 1}"
  )
  user_data_replace_on_change = true

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.storage_instance_type

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  vpc_security_group_ids = [
    aws_security_group.talos_api.id, # Talos API access
    aws_security_group.internal.id,  # Internal communication within the VPC
    aws_security_group.efs_sg.id,    # EFS access for file systems
  ]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Add tags to the instance for identification and management.
  tags = {
    Name = "storage${count.index + 1}"
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
