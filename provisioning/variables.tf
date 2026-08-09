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
  description = "Number of login node EC2 instances to create in the cluster"
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
  description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"
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
  description = "AMI ID for the controller node"
  type        = string
  default     = "ami-020cba7c55df1f615"
}

variable "login_ami" {
  description = "AMI ID for the login node"
  type        = string
  default     = "ami-020cba7c55df1f615"
}

variable "worker_cpu_ami" {
  description = "AMI ID for compute nodes"
  type        = string
  default     = "ami-020cba7c55df1f615"
}

variable "worker_gpu_ami" {
  description = "AMI ID for compute nodes"
  type        = string
  default     = "ami-020cba7c55df1f615"
}

variable "storage_ami" {
  description = "AMI ID for storage nodes"
  type        = string
  default     = "ami-020cba7c55df1f615"
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "target_az" {
  description = "Availability Zone to use for resources (must match capacity reservation)"
  type        = string
  default     = "us-east-1c"
}




