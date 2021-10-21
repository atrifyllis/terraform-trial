resource "aws_autoscaling_group" "ecs_asg" {
  name = "ecs-asg"

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id = aws_launch_template.ecs_launch_template.id
  }

  min_size         = 1
  max_size         = 2
  desired_capacity = 2

}

resource "aws_launch_template" "ecs_launch_template" {
  name = "ecs-launch-template"

  key_name      = "ec2-par" # ssh key created outside of terraform
  image_id      = data.aws_ami.ecs_optimized_ami.id
  instance_type = "t2.small"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  # IMPORTANT!   install ec2 instance connect (optional)
  # and register instances to the correct ecs cluster!!!! otherwise asg will register them in default cluster
  user_data = base64encode(data.template_file.launch_template_user_data.rendered)

  update_default_version = true
}


resource "aws_security_group" "instance_sg" {
  name        = "instance-security-group"
  description = "controls direct access to application instances"
  vpc_id      = var.vpc_id

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IMPORTANT! this is how we connect asg with alb!
resource "aws_autoscaling_attachment" "asg_alb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
  alb_target_group_arn   = var.alb_target_group_arn
}


data "template_file" "launch_template_user_data" {
  template = file("${path.module}/launch_template_user_data.sh")

  vars = {
    cluster_name = var.ecs_cluster_name
  }
}

data "aws_ami" "ecs_optimized_ami" {
  owners = ["amazon"]

  #  filter amis by name and retrieve the ecs optimized one:
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.20211013-x86_64-ebs"]
  }

  most_recent = true
}
