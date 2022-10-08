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
}

module "eks" {
  source            = "./modules/eks"
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  security_group_id = aws_security_group.node_group_one.id
  region            = var.aws_region
}
