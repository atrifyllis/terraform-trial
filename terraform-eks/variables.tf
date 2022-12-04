variable "aws_region" {
  default = "us-east-1"
}
variable "chart_version_aws_ebs_csi_driver" {
  default = "1.13.0"
}

variable "common_name" {
  default = "*.senik.tk"
}

variable "lets_encrypt_url" {
  default = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

