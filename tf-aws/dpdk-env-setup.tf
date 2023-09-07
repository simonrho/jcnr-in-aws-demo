locals {
  gateway_address = cidrhost(var.peering_subnet, 1)
}

resource "kubernetes_namespace" "dpdk_env" {
  depends_on = [ 
    aws_eks_cluster.demo1,
    null_resource.update_kubeconfig
  ]

  metadata {
    name = "dpdk-env"
  }
}

data "template_file" "user_data" {
  template = file("dpdk-env-setup.sh")

  vars = {
    peer_vpc_cidr    = var.peer_vpc_cidr
    peering_next_hop = local.gateway_address
  }
}

resource "kubernetes_config_map" "node_setup" {
  depends_on = [ 
    aws_eks_cluster.demo1,
    null_resource.update_kubeconfig,
    kubernetes_namespace.dpdk_env
  ]

  metadata {
    name      = "dpdk-env-setup-cm"
    namespace = kubernetes_namespace.dpdk_env.metadata[0].name
  }

  data = {
    "dpdk-env-setup.sh" = data.template_file.user_data.rendered
  }
}

resource "kubernetes_daemonset" "dpdk-env-setup" {
  depends_on = [ 
    aws_eks_cluster.demo1,
    null_resource.update_kubeconfig,
    kubernetes_namespace.dpdk_env
  ]

  metadata {
    name      = "dpdk-env-setup"
    namespace = kubernetes_namespace.dpdk_env.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        "app" = "dpdk-env-setup"
      }
    }

    template {
      metadata {
        labels = {
          "app" = "dpdk-env-setup"
        }
      }

      spec {
        node_selector = var.node_selector

        host_network = true

        container {
          image   = "alpine:latest"
          name    = "idle-container"
          command = ["/bin/sh", "-c", "cp /configmap/dpdk-env-setup.sh /host/root/dpdk-env-setup.sh && chmod +x /host/root/dpdk-env-setup.sh && chroot /host /root/dpdk-env-setup.sh && sleep infinity"]

          security_context {
            privileged = true
          }
          volume_mount {
            name       = "host-root"
            mount_path = "/host"
          }

          volume_mount {
            name       = "user-script"
            mount_path = "/configmap"
          }
        }

        volume {
          name = "host-root"

          host_path {
            path = "/"
            type = "Directory"
          }
        }

        volume {
          name = "user-script"

          config_map {
            name = kubernetes_config_map.node_setup.metadata[0].name
          }
        }
      }
    }
  }
}
