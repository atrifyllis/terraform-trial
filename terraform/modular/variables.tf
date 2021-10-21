variable "aws_region" {
  default = "eu-west-2"
}

variable "ec2_log_group" {
  default = "ec2-log-group/app"
}

variable "container_port" {
  default = 8080
}

variable "alb_port" {
  default = 80
}
