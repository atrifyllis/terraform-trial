provider "aws" {
  region = var.aws_region
}


terraform {
  backend "s3" {
    bucket         = "alxeks1state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1" # variables not allowed here
    dynamodb_table = "alxeks1table"
  }
}

/*module "vpc" {
  source = "./modules/vpc"
}*/

# creates LetsEncrypt certificate and links it with Route53 host zone
module "certificate" {
  source           = "./modules/certificate"
  common_name      = var.common_name
  lets_encrypt_url = var.lets_encrypt_url
}


