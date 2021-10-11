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

  # the IAM Instance profile (?) to launch the instance with:
  iam_instance_profile_arn = aws_iam_instance_profile.asg-iam-ip.arn

  # the security groups that will be linked to ec2 instances:
  security_groups = [
    module.ec2_sg.security_group_id
  ]
}

resource "aws_iam_instance_profile" "asg-iam-ip" {
  name = "asg-iam-instance-profile"
  role = aws_iam_role.asg-iam-role.name
}

resource "aws_iam_role" "asg-iam-role" {
  name               = "asg-iam-role"
  assume_role_policy = data.aws_iam_policy_document.asg_iam_policy_doc.json
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "spring-boot-test"

  capacity_providers = ["EC2"]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.prov1.name
    weight = 1
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_ecs_capacity_provider" "prov1" {
  name = "prov1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = module.asg.autoscaling_group_arn
  }

}


# roughly, this a service policy which enables ec2 service to assume the role to which it is attached (see role above)
data "aws_iam_policy_document" "asg_iam_policy_doc" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = [
    "amazon"
  ]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2"
    ]
  }
}
