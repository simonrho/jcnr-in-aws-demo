output "aws_region" {
  value = var.aws_region
}

output "cluster_name" {
  value = var.cluster_name
}

output "ces" {
  value       = aws_instance.ce_instance[*].public_dns
  description = "The public DNS of the CE instances"
}
