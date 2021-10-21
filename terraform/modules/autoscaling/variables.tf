variable "subnet_ids" {}

variable "vpc_id" {}

variable "instance_profile_arn" {
  type = string
}

variable "alb_target_group_arn" {}

variable "container_port" {}


variable "ecs_cluster_name" {
}
