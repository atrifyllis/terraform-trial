variable "aws_region" {
  default = "eu-west-2"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "ecs_cidr_block" {
  default = "10.0.0.0/16"
}
variable "ecs_vpc_name" {
  default = "ecs-vpc"
}
