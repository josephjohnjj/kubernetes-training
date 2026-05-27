

variable "compute_node_count" {
  description = "Number of compute node EC2 instances to create in the cluster"
  type        = number
  default     = 3
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
# Input Variable Declaration: instance_name
# -----------------------------------------------------
variable "instance_name" {
  # A human-readable explanation of what this variable is for.
  # In this case, it is used to set the 'Name' tag on the EC2 instance.
  description = "Value of the Name tag for the EC2 instance"

  # The expected type for this variable (a plain string).
  type = string

  # The default value to use if no value is provided in a .tfvars file
  # or via the command line. This means the variable is optional.
  default = "Slurm-Server"
}


# -----------------------------------------------------
# Input Variable Declaration: instance_type
# -----------------------------------------------------
variable "instance_type" {
  # A human-readable description that explains what this variable does.
  # This value sets the EC2 instance type, such as t2.micro (free tier),
  # or a powerful GPU instance like p3.2xlarge.
  #
  # You can find a list of available EC2 instance types in the AWS docs:
  # https://aws.amazon.com/ec2/instance-types/
  description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"

  # The type of value this variable expects: a plain string.
  type = string

  # The default value used if no value is provided in .tfvars or CLI.
  # This defaults to a general-purpose free-tier eligible instance.
  default = "t2.micro"
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

variable "compute_ami" {
  description = "AMI ID for compute nodes"
  type        = string
  default     = "ami-020cba7c55df1f615"
}

variable "storage_ami" {
  description = "AMI ID for storage nodes"
  type        = string
  default     = "ami-020cba7c55df1f615"
}



# -----------------------------------------------------
# Input Variable Declaration: capacity_reservation_id
# -----------------------------------------------------
variable "capacity_reservation_id" {
  # A human-readable explanation of what this variable is for.
  # This variable holds the ID of an existing EC2 Capacity Reservation
  # that the EC2 instance should be launched into.
  #
  # If this variable is set to an empty string (default),
  # no capacity reservation will be used and the instance
  # will launch as a normal On-Demand instance without reservation.
  description = "The ID of the existing EC2 Capacity Reservation to use (empty string for none)"

  # The expected type for this variable (a plain string).
  type = string

  # Default value is empty string indicating no capacity reservation.
  default = ""
}


variable "target_az" {
  description = "Availability Zone to use for resources (must match capacity reservation)"
  type        = string
  default     = "us-east-1c"
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1" # Optional default
}


