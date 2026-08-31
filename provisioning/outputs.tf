############################################
# Terraform Output Definitions by Node Role
############################################

# --------------------------------------------
# Control Node
# --------------------------------------------
output "control_node_public_ip" {
  description = "Public IP address of the control node"
  value       = [for i in aws_instance.control_node : i.public_ip]
}

output "control_node_private_ip" {
  description = "Private IP address of the control node"
  value       = [for i in aws_instance.control_node : i.private_ip]
}

output "controlplane_api_public_ip" {
  description = "Stable Elastic IP attached to control1 and used as the Kubernetes API endpoint"
  value       = aws_eip_association.controlplane_api.public_ip
}

# --------------------------------------------
# Ingress workers (Terraform resource is temporarily named login_node)
# --------------------------------------------
output "login_node_public_ips" {
  description = "Stable public Elastic IP addresses of the Talos ingress workers"
  value       = [for i in aws_eip.ingress : i.public_ip]
}

output "login_node_private_ips" {
  description = "Private IP addresses of the Talos ingress workers"
  value       = [for i in aws_instance.login_node : i.private_ip]
}

# --------------------------------------------
# Worker Nodes (without GPU)
# --------------------------------------------
output "worker_node_cpu_public_ips" {
  description = "Public IPs of the compute nodes (optional)"
  value       = [for i in aws_instance.worker_node_cpu : i.public_ip]
}

output "worker_node_cpu_private_ips" {
  description = "Private IPs of the compute nodes"
  value       = [for i in aws_instance.worker_node_cpu : i.private_ip]
}

# --------------------------------------------
# Worker Nodes (without GPU)
# --------------------------------------------
output "worker_node_gpu_public_ips" {
  description = "Public IPs of the compute nodes (optional)"
  value       = [for i in aws_instance.worker_node_gpu : i.public_ip]
}

output "worker_node_gpu_private_ips" {
  description = "Private IPs of the compute nodes"
  value       = [for i in aws_instance.worker_node_gpu : i.private_ip]
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
