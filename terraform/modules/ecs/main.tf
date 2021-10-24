resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.prefix}-ecs-cluster"
}


resource "aws_ecs_service" "ecs_service" {
  name = "${var.prefix}-ecs-service"

  cluster                            = aws_ecs_cluster.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  # required when using load balancer! (dont use it if task has awsvpc network)
  iam_role                           = aws_iam_role.ecs_iam_role.name

  load_balancer {
    container_name   = var.container_name
    container_port   = var.container_port
    target_group_arn = var.alb_target_group_arn
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                = "${var.prefix}-ecs-task-terraform"
  container_definitions = data.template_file.ecs_task_definition_template.rendered
}

resource "aws_iam_role" "ecs_iam_role" {
  name               = "${var.prefix}-ecs-iam-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_iam_policy_doc.json
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs-service-role-policy"
  role   = aws_iam_role.ecs_iam_role.id
  policy = data.template_file.ecs_service_policy_file.rendered
}

# attach policy to role:
#resource "aws_iam_role_policy_attachment" "ecs_role_policy_attachement" {
#  policy_arn = aws_iam_role_policy.ecs_service_role_policy.
#  role       = aws_iam_role.ecs_iam_role.name
#}


data "template_file" "ecs_task_definition_template" {
  template = file("${path.module}/templates/task-definition.json")

  vars = {
    image_url        = var.image_url
    container_name   = var.container_name
    container_port   = var.container_port
    log_group_name   = var.log_group_name
    log_group_region = var.aws_region
  }
}

data "aws_iam_policy_document" "ecs_iam_policy_doc" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = [
        "ecs.amazonaws.com"
      ]
    }
  }
}

# counter-intuitive policies, where the ecs instance must have ec2 and alb policies
data "template_file" "ecs_service_policy_file" {
  template = file("${path.module}/templates/ecs_service_policy.json")
}

