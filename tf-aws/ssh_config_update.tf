resource "null_resource" "update_ssh_config" {
  count = length(var.vpc_secondary_subnets)

  # This ensures that the provisioner will run again if the instance or key path changes
  triggers = {
    # always_run = "${timestamp()}"
    instance_public_dns = aws_instance.ce_instance[count.index].public_dns
    ssh_key_path        = local_sensitive_file.my_private_key_file.filename
    hostname_alias      = var.vpc_secondary_subnets[count.index].hostname
  }

  provisioner "local-exec" {
    command = <<-EOT
      ./ssh_config_update.sh \
      ${var.vpc_secondary_subnets[count.index].hostname} \
      ${aws_instance.ce_instance[count.index].public_dns} \
      ${local_sensitive_file.my_private_key_file.filename}
    EOT
    on_failure = continue
  }

  # Ensure this runs after the EC2 instance is fully created.
  depends_on = [aws_instance.ce_instance]
}

