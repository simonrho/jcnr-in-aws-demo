output "aws_region" {
  value = var.aws_region
}

output "cluster_name" {
  value = var.cluster_name
}

output "ce_instance_public_ips" {
  value       = aws_instance.ce_instance[*].public_ip
  description = "The public IPs of the CE instances"
}

