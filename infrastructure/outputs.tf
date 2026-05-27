############################################
# Terraform Output Definitions by Node Role
############################################

# --------------------------------------------
# Control Node
# --------------------------------------------
output "control_node_public_ip" {
  description = "Public IP address of the control node"
  value       = aws_instance.control_node.public_ip
}

output "control_node_private_ip" {
  description = "Private IP address of the control node"
  value       = aws_instance.control_node.private_ip
}

# --------------------------------------------
# Login Nodes (can be multiple)
# --------------------------------------------
output "login_node_public_ips" {
  description = "Public IP addresses of the login nodes"
  value       = [for i in aws_instance.login_node : i.public_ip]
}

output "login_node_private_ips" {
  description = "Private IP addresses of the login nodes"
  value       = [for i in aws_instance.login_node : i.private_ip]
}

# --------------------------------------------
# Compute Nodes (usually many)
# --------------------------------------------
output "compute_node_public_ips" {
  description = "Public IPs of the compute nodes (optional)"
  value       = [for i in aws_instance.compute_node : i.public_ip]
}

output "compute_node_private_ips" {
  description = "Private IPs of the compute nodes"
  value       = [for i in aws_instance.compute_node : i.private_ip]
}

# --------------------------------------------
# Storage_node Nodes (usually many)
# --------------------------------------------
output "storage_node_public_ips" {
  description = "Public IPs of the storage nodes (optional)"
  value       = [for i in aws_instance.storage_node : i.public_ip]
}

output "storage_node_private_ips" {
  description = "Private IPs of the storage nodes"
  value       = [for i in aws_instance.storage_node : i.private_ip]
}

# --------------------------------------------
# EFS IDs
# --------------------------------------------
output "efs_apps_id" {
  description = "EFS File System ID for /apps mount"
  value       = aws_efs_file_system.apps.id
}

output "efs_scratch_id" {
  description = "EFS File System ID for /scratch mount"
  value       = aws_efs_file_system.scratch.id
}

output "efs_home_id" {
  description = "EFS File System ID for /home mount"
  value       = aws_efs_file_system.home.id
}
