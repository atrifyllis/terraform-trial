provider "aws" {
  region = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket         = "trififormstate"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "trifitable"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "trifi-vpc"
  cidr = "10.0.0.0/16"

  azs             = [
    "eu-west-2a",
    "eu-west-2b"
  ]
  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
  public_subnets  = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]


  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name = "ec2_security-group"

  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}


module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"

  name = "ec2-autoscaling-group"

  vpc_zone_identifier = module.vpc.private_subnets

  # Create both the autoscaling group and launch template:
  use_lt    = true
  create_lt = true

  min_size                  = 0
  max_size                  = 2
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.small"
}


data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2"
    ]
  }
}
