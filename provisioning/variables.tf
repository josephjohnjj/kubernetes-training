# -----------------------------------------------------
# Input Variable Declaration: instance count
# -----------------------------------------------------

variable "worker_node_cpu_count" {
  description = "Number of worker node EC2 instances to create in the cluster"
  type        = number
  default     = 2
}

variable "worker_node_gpu_count" {
  description = "Number of worker node EC2 instances to create in the cluster"
  type        = number
  default     = 2
}

variable "storage_node_count" {
  description = "Number of storage node EC2 instances to create in the cluster"
  type        = number
  default     = 3
}

variable "login_node_count" {
  description = "Number of Talos ingress worker instances (temporarily named login nodes)"
  type        = number
  default     = 1
}

variable "control_node_count" {
  description = "Number of control node EC2 instances to create in the cluster"
  type        = number
  default     = 3
}



# -----------------------------------------------------
# Input Variable Declaration: instance type
# -----------------------------------------------------

variable "control_instance_type" {
  description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"
  type        = string
  default     = "t3.2xlarge"
}


variable "login_instance_type" {
  description = "EC2 instance type for each Talos ingress worker"
  type        = string
  default     = "t3.small"
}

variable "worker_cpu_instance_type" {
  description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"
  type        = string
  default     = "t3.2xlarge"
}

variable "worker_gpu_instance_type" {
  description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"
  type        = string
  default     = "t3.2xlarge"
}

variable "storage_instance_type" {
  description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"
  type        = string
  default     = "t3.2xlarge"
}



# -----------------------------------------------------
# Input Variable Declaration: ami
# -----------------------------------------------------

variable "controller_ami" {
  description = "Talos AWS AMI ID for control-plane nodes"
  type        = string
}

variable "login_ami" {
  description = "Talos AWS AMI ID for the ingress worker temporarily named login1"
  type        = string
}

variable "talos_api_allowed_cidrs" {
  description = "Networks allowed to manage Talos nodes over TCP 50000; set this to a VPN or administrator CIDR"
  type        = list(string)
  default     = []
}

variable "controlplane_api_eip_allocation_id" {
  description = "Allocation ID of the preallocated Elastic IP attached to control1 for the Kubernetes API endpoint"
  type        = string

  validation {
    condition     = can(regex("^eipalloc-[0-9a-f]+$", var.controlplane_api_eip_allocation_id))
    error_message = "Provide an AWS Elastic IP allocation ID such as eipalloc-0123456789abcdef0."
  }
}

variable "controlplane_machine_config" {
  description = "Generated Talos controlplane.yaml supplied to EC2 user data"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.controlplane_machine_config) > 0 &&
      length(var.controlplane_machine_config) <= 16384 &&
      strcontains(var.controlplane_machine_config, "kind: HostnameConfig") &&
      strcontains(var.controlplane_machine_config, "auto: stable")
    )
    error_message = "The control-plane machine config must fit the EC2 16 KiB limit and contain the Talos 1.13 HostnameConfig with auto: stable."
  }
}

variable "worker_machine_config" {
  description = "Generated Talos worker.yaml supplied to ordinary, GPU, and storage worker user data"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.worker_machine_config) > 0 &&
      length(var.worker_machine_config) <= 16384 &&
      strcontains(var.worker_machine_config, "kind: HostnameConfig") &&
      strcontains(var.worker_machine_config, "auto: stable")
    )
    error_message = "The worker machine config must fit the EC2 16 KiB limit and contain the Talos 1.13 HostnameConfig with auto: stable."
  }
}

variable "ingress_machine_config" {
  description = "Generated Talos ingress.yaml supplied to the login1 ingress worker user data"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.ingress_machine_config) > 0 &&
      length(var.ingress_machine_config) <= 16384 &&
      strcontains(var.ingress_machine_config, "kind: HostnameConfig") &&
      strcontains(var.ingress_machine_config, "auto: stable")
    )
    error_message = "The ingress machine config must fit the EC2 16 KiB limit and contain the Talos 1.13 HostnameConfig with auto: stable."
  }
}

variable "worker_cpu_ami" {
  description = "Talos AWS AMI ID for CPU worker nodes"
  type        = string
}

variable "worker_gpu_ami" {
  description = "Talos AWS AMI ID containing the required GPU system extensions"
  type        = string
}

variable "storage_ami" {
  description = "Talos AWS AMI ID for Rook-Ceph storage workers"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "target_az" {
  description = "Single availability zone used by every Talos node"
  type        = string
  default     = "us-east-1c"
}

variable "public_subnet_cidr" {
  description = "Subnet CIDR for all Talos nodes; must not overlap the pod or service networks"
  type        = string
  default     = "10.0.1.0/24"
}
