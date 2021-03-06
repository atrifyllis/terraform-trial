resource "aws_alb" "ecs_load_balancer" {
  name = "${var.prefix}-ecs-load-balancer"

  internal = false

  subnets         = var.subnet_ids
  security_groups = [aws_security_group.alb_sg.id]
}


resource "aws_alb_target_group" "ecs_alb_target_group" {
  name     = "${var.prefix}-alb-target-group"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  deregistration_delay = 10

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
    path                = var.health_check_path
    port                = var.container_port
  }
}


resource "aws_alb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_alb.ecs_load_balancer.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_alb_target_group.arn
  }
}


resource "aws_security_group" "alb_sg" {
  name        = "${var.prefix}-application-load-balancer-security-group"
  description = "controls direct access to load balancer"

  vpc_id = var.vpc_id

  ingress {
    from_port   = var.alb_port
    to_port     = var.alb_port
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
