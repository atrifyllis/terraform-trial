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
    },
    {
      from_port   = 8080
      to_port     = 8080 # this is the instance port
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}


module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"

  name = "ec2-autoscaling-group"

  vpc_zone_identifier = module.vpc.public_subnets

  # Create both the autoscaling group and launch template:
  use_lt    = true
  create_lt = true

  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.small"

  associate_public_ip_address = true

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

resource "aws_iam_role" "ecs-iam-role" {
  name               = "ecs-iam-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_iam_policy_doc.json
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name = "ecs_service_role_policy"
  role = aws_iam_role.ecs-iam-role.name

  policy = jsonencode(
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:Describe*",
          "ec2:AuthorizeSecurityGroupIngress",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:RegisterTargets",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  }
  )
}

resource "aws_iam_role_policy" "ec2_role_policy" {
  name = "ec2_role_policy"
  role = aws_iam_role.asg-iam-role.name

  policy = jsonencode(
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "ec2-instance-connect:SendSSHPublicKey",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : { "ec2:osuser" : "ec2-user" }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : "ec2:DescribeInstances",
        "Resource" : "*"
      }
    ]
  }
  )
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "spring-boot-test"

  #  capacity_providers = ["spring-boot-capacity-provider"]
  #
  #  default_capacity_provider_strategy {
  #    capacity_provider = aws_ecs_capacity_provider.ecs-capacity-provider.name
  #    weight            = 1
  #  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#resource "aws_ecs_capacity_provider" "ecs-capacity-provider" {
#  name = "spring-boot-capacity-provider"
#
#  auto_scaling_group_provider {
#    auto_scaling_group_arn = module.asg.autoscaling_group_arn
#  }
#
#}


resource "aws_ecs_service" "spring-boot-service" {
  name            = "spring-boot-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.spring-boot-task.arn
  desired_count   = 2
  iam_role        = aws_iam_role.ecs-iam-role.arn # dont use it with task with awsvpc

  load_balancer {
    target_group_arn = aws_alb_target_group.alb-target-group.arn
    container_name   = "terraform-trial"
    container_port   = "8080"
  }

  depends_on = [
    aws_iam_role.ecs-iam-role,
    aws_alb_listener.alb-listener,
  ]
}

resource "aws_ecs_task_definition" "spring-boot-task" {
  family                = "spring-boot-task"
  container_definitions = data.template_file.task_definition.rendered
  execution_role_arn    = aws_iam_role.ecs-iam-role.arn
  #  network_mode = "awsvpc"
}

# ALB

resource "aws_alb_listener" "alb-listener" {
  load_balancer_arn = aws_alb.test-load-balancer.arn
  port              = "80"  # should be the same as the sg inbound rule  port!
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb-target-group.arn
    type             = "forward"
  }
}

resource "aws_alb" "test-load-balancer" {
  name            = "spring-boot-alb"
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]
}

resource "aws_alb_target_group" "alb-target-group" {
  name     = "spring-boot-alb-target-group"
  port     = 8080 # Port on which targets receive traffic, is it the ec2
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    path     = "/hello"
    interval = 15
    timeout  = 10
  }
}

module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name = "alb_security-group"

  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      protocol    = "tcp"
      from_port   = 80 # should be the same as the listener port!
      to_port     = 80
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

# LOGS

resource "aws_cloudwatch_log_group" "app" {
  name              = "/spring-boot-test/app"
  retention_in_days = 1
}

# DATA

data "template_file" "task_definition" {
  template = file("${path.module}/templates/task-definition.json")

  vars = {
    image_url        = "otinanism/terraform-trial:latest"
    container_name   = "terraform-trial"
    log_group_region = var.aws_region
    #    log_group_name   = aws_cloudwatch_log_group.app.name
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
        "ec2.amazonaws.com",
        "ssm.amazonaws.com"
      ]
    }
  }
}

# and this is is for ECS
data "aws_iam_policy_document" "ecs_iam_policy_doc" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
  role       = aws_iam_role.ecs-iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = [
    "amazon"
  ]

  filter {
    name = "name"

    values = [
      "amzn-ami-*-amazon-ecs-optimized"
    ]
  }
}
