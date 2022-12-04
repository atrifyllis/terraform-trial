provider "aws" {
  region = var.aws_region
}


terraform {
  backend "s3" {
    bucket         = "alxeks1state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1" # variables not allowed here
    dynamodb_table = "alxeks1table"
  }
}

module "vpc" {
  source = "./modules/vpc"
}

resource "aws_security_group" "node_group_one" {
  name_prefix = "node_group_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  ingress {
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    description = "Allow access from control plane to webhook port of AWS load balancer controller"
    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

module "eks" {
  source            = "./modules/eks"
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  security_group_id = aws_security_group.node_group_one.id
  region            = var.aws_region
  public_subnets    = module.vpc.public_subnets
}

# Links Kubernetes Ingresses with AWS ALBs
module "alb-controller" {
  source            = "./modules/alb-controller"
  oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id            = module.vpc.vpc_id
  eks_name          = module.eks.cluster_name
}

# Links AWS ALBs with Route53 host zones.
module "external_dns" {
  source = "git::https://github.com/DNXLabs/terraform-aws-eks-external-dns.git"

  cluster_name                     = module.eks.cluster_id
  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn

  settings = {
    "policy" = "sync" # Modify how DNS records are sychronized between sources and providers.
  }
}

# creates LetsEncrypt certificate and links it with Route53 host zone
module "certificate" {
  source           = "./modules/certificate"
  common_name      = var.common_name
  lets_encrypt_url = var.lets_encrypt_url
}

# ebs to pvc
module "ebs_csi_driver_controller" {
  source  = "DrFaust92/ebs-csi-driver/kubernetes"
  version = "3.5.0"

  ebs_csi_controller_image                   = ""
  ebs_csi_controller_role_name               = "ebs-csi-driver-controller"
  ebs_csi_controller_role_policy_name_prefix = "ebs-csi-driver-policy"
  oidc_url                                   = module.eks.cluster_oidc_issuer_url
}

# needed to create service account (at least)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_cert)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_cert)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}
