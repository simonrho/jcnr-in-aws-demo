resource "null_resource" "vpc_peering_handler" {

  triggers = {
    create_command = "./vpc-peering.sh delete-and-create ${var.cluster_name} ${var.aws_region} ${var.peer_cluster_name} ${var.peer_region} ${var.vpc_cidr_block} ${var.peer_vpc_cidr}"
    delete_command = "./vpc-peering.sh delete ${var.cluster_name} ${var.aws_region} ${var.peer_cluster_name} ${var.peer_region} ${var.vpc_cidr_block} ${var.peer_vpc_cidr}"
  }

  # For the create event
  provisioner "local-exec" {
    command = self.triggers.create_command
    on_failure = continue
  }

  # For the destroy event
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete_command
    on_failure = continue
  }

  depends_on = [
    aws_route_table_association.demo1
  ]
}
