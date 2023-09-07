variable "aws_region" {
  default = "us-east-2"
}

variable "cluster_name" {
  default = "tf-demo1-eks"
  type    = string
}

variable "cluster_version" {
  default = "1.27"
  type = string
}

variable "node_instance_type" {
  default = "m5.4xlarge"
  type = string
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
  type    = string
}

variable "vpc_subnets" {
  default = [
    { name = "subnet1", cidr = "10.0.0.0/24" },
    { name = "subnet2", cidr = "10.0.1.0/24" }
  ]
  type = list(object({
    name = string
    cidr = string
  }))
}

variable "peering_setup_flag" {
  default = true
  type = bool
}

variable "peering_subnet" {
  default = "10.0.255.0/24"
  type    = string
}

variable "peer_vpc_cidr" {
  default = "172.16.0.0/16"
  type    = string
}

variable "peer_region" {
  default = "us-west-2"
  type    = string
}

variable "peer_cluster_name" {
  default = "tf-demo2-eks"
  type    = string
}

variable "vpc_secondary_cidr_block" {
  default = "10.1.0.0/16"
  type    = string
}

variable "vpc_secondary_subnets" {
  default = [
    { name = "subnet1", cidr = "10.1.0.0/24", peer_cidr = "172.17.0.0/24", hostname = "Westford" },
    { name = "subnet2", cidr = "10.1.1.0/24", peer_cidr = "172.17.1.0/24", hostname = "BOS" }
  ]
  type = list(object({
    name = string
    cidr = string
    peer_cidr = string
    hostname = string
  }))
}

variable "node_selector" {
  description = "Node selector key-value for the Kubernetes DaemonSet adding DPDK env setup in target nodes"
  type        = map(string)
  default     = {
    "key1" = "jcnr"
  }
}
