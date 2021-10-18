provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket         = "trififormstate"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "trifitable"
  }
}


module "ecs_vpc" {
  source = "../modules/vpc"
}

module "ec2_instance_profile" {
  source = "../modules/ec2_instance_profile"
}
module "ecs_autoscaling_group" {
  source               = "../modules/autoscaling"
  vpc_id               = module.ecs_vpc.vpc_id
  subnet_ids           = module.ecs_vpc.vpc_subnet_ids
  instance_profile_arn = module.ec2_instance_profile.instance_profile_arn
  # IMPORTANT! this is how we connect asg with alb!
  alb_target_group_arn = module.ecs_load_balancer.alb_target_group_arn
}

module "ecs_load_balancer" {
  source     = "../modules/alb"
  vpc_id     = module.ecs_vpc.vpc_id
  subnet_ids = module.ecs_vpc.vpc_subnet_ids
}
