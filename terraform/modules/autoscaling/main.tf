resource "aws_autoscaling_group" "ecs_asg" {
  name = "ecs_asg"

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id = aws_launch_template.ecs_launch_template.id
  }

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

}

resource "aws_launch_template" "ecs_launch_template" {
  name = "ecs_launch_template"

  # name of the instance
  #  key_name      = "ecs_instance"
  image_id      = data.aws_ami.ecs_optimized_ami.id
  instance_type = "t2.small"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  #  vpc_security_group_ids = [aws_security_group.instance_sg.id] conflicts with network_interfaces
}

resource "aws_security_group" "instance_sg" {
  name        = "instance_security_group"
  description = "controls direct access to application instances"
  vpc_id      = var.vpc_id

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "ecs_optimized_ami" {
  owners = ["amazon"]

  #  filter amis by name and retrieve the ecs optimized one:
  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  most_recent = true
}
