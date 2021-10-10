provider "aws" {
  region = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket = "trififormstate"
    key = "global/s3/terraform.tfstate"
    region = "eu-west-2"
    dynamodb_table = "trifitable"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "trifi-vpc"
  cidr = "10.0.0.0/16"

  azs = [
    "eu-west-2a",
    "eu-west-2b"]
  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"]
  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24"]


  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
    }
  ]
}
