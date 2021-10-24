variable "vpc_id" {}

variable "subnet_ids" {
  type = list(string)
}

variable "container_port" {}

variable "alb_port" {}

variable "prefix" {
}

variable "health_check_path" {
}
