module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.16.0"

  name = "ecs-vpc"

  cidr = "10.0.0.0/16"
  azs  = ["us-east-1a", "us-east-1f"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24"]

  enable_nat_gateway   = false
#  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}


locals {
  cluster_name = var.clustername
}
#
#module "nat" {
#  source = "int128/nat-instance/aws"
#
#  name                        = "main"
#  vpc_id                      = module.vpc.vpc_id
#  public_subnet               = module.vpc.public_subnets[0]
#  private_subnets_cidr_blocks = module.vpc.private_subnets_cidr_blocks
#  private_route_table_ids     = module.vpc.private_route_table_ids
#}
#
#resource "aws_eip" "nat" {
#  network_interface = module.nat.eni_id
#  tags = {
#    "Name" = "nat-instance-main"
#  }
#}
