terraform {
  required_providers {
    kops = {
      source = "eddycharly/kops"
    }
  }
  backend "s3" {
    bucket         = "alxeks1state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1" # variables not allowed here
    dynamodb_table = "alxeks1table"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kops" {
  state_store = "s3://alxeks1kops"
}


# creates LetsEncrypt certificate and links it with Route53 host zone
module "certificate" {
  source           = "./modules/certificate"
  common_name      = var.common_name
  lets_encrypt_url = var.lets_encrypt_url
}

module "vpc" {
  source = "./modules/vpc"
}

resource "kops_cluster" "cluster" {
  name       = var.cluster_name
  dns_zone   = var.dns_zone
  network_id = module.vpc.vpc_id

  cloud_provider {
    aws {}
  }


  etcd_cluster {
    name = "main"
    member {
      name           = "master-0"
      instance_group = "master-us-east-1a"
    }
  }

  etcd_cluster {
    name = "events"
    member {
      name           = "master-0"
      instance_group = "master-us-east-1a"
    }
  }

  iam {
    allow_container_registry                 = true
    legacy                                   = false
    use_service_account_external_permissions = true
  }

  kubelet {
    anonymous_auth {
      value = false
    }
  }

  kubernetes_api_access = ["0.0.0.0/0", "::/0"]

  networking {
    kubenet {}
  }

  service_account_issuer_discovery {
    discovery_store          = "s3://alxeks1kopsoidcstore/kops.senik.tk/discovery/kops.senik.tk"
    enable_aws_oidc_provider = true
  }

  ssh_access = ["0.0.0.0/0", "::/0"]

  subnet {
    name        = "ecs-vpc-public-us-east-1a"
    type        = "Public"
    provider_id = module.vpc.public_subnets[0]
    zone        = "us-east-1a"
  }

  subnet {
    name        = "ecs-vpc-public-us-east-1f"
    type        = "Public"
    provider_id = module.vpc.public_subnets[1]
    zone        = "us-east-1f"
  }

  topology {
    masters = "public"
    nodes   = "public"
    dns {
      type = "Public"
    }
  }

  aws_load_balancer_controller {
    enabled = true
  }

  cert_manager {
    enabled = true
    managed = true
  }

  external_dns {
    provider      = "external-dns"
    watch_ingress = true
  }
}


resource "kops_instance_group" "master-us-east-1a" {
  labels = {
    "kops.k8s.io/cluster" = "dev.senik.tk"
  }
  cluster_name = kops_cluster.cluster.id
  name         = "master-us-east-1a"
  role         = "Master"
  min_size     = 1
  max_size     = 1
  machine_type = var.machineType
  subnets      = ["ecs-vpc-public-us-east-1a"]
  image        = "099720109477/ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20221018"
  max_price    = "0.007"

  mixed_instances_policy {
    spot_allocation_strategy = "lowest-price"
  }
}

resource "kops_instance_group" "nodes-us-east-1f" {
  labels = {
    "kops.k8s.io/cluster" = "dev.senik.tk"
  }
  cluster_name = kops_cluster.cluster.id
  name         = "master-us-east-1f"
  role         = "Node"
  min_size     = 2
  max_size     = 2
  machine_type = var.machineType
  subnets      = ["ecs-vpc-public-us-east-1f"]
  image        = "099720109477/ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20221018"
  max_price    = "0.009"

  mixed_instances_policy {
    spot_allocation_strategy = "lowest-price"
  }
}


resource "kops_cluster_updater" "updater" {
  cluster_name = kops_cluster.cluster.name

  keepers = {
    cluster  = kops_cluster.cluster.revision
    master-0 = kops_instance_group.master-us-east-1a.revision
    nodes-0  = kops_instance_group.nodes-us-east-1f.revision
  }

  rolling_update {
    skip                = true
#    fail_on_drain_error = true
    #    fail_on_validate    = false
    #    validate_count      = 1

  }

  validate {
    skip = true

  }

  # ensures rolling update happens after the cluster and instance groups are up to date
  depends_on = [
    kops_cluster.cluster,
    kops_instance_group.master-us-east-1a,
    kops_instance_group.nodes-us-east-1f
  ]
}
#
#data "kops_kube_config" "kube_config" {
#  cluster_name = kops_cluster.cluster.id
#}
