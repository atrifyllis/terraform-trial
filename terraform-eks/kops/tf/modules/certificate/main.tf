# Generates a LetsEncrypt certificate using AWS Route53 for challenge and stores it also in Route53

terraform {
  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "2.11.1"
    }
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "reg_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.reg_private_key.private_key_pem
  email_address   = var.email
}

resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "req" {
  private_key_pem = tls_private_key.cert_private_key.private_key_pem

  subject {
    common_name = var.common_name
  }
}

resource "acme_certificate" "certificate" {
  account_key_pem         = acme_registration.reg.account_key_pem
  certificate_request_pem = tls_cert_request.req.cert_request_pem

  dns_challenge {
    provider = "route53"
  }
}

resource "aws_acm_certificate" "acm_certificate" {
  certificate_body  = acme_certificate.certificate.certificate_pem
  private_key       = tls_private_key.cert_private_key.private_key_pem # trap! not from acme_certificate!
  certificate_chain = acme_certificate.certificate.issuer_pem
}
