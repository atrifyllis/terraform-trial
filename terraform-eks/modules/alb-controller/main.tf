module "lb_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "${var.env_name}_eks_lb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-service-account"]
    }
  }
}

resource "kubernetes_service_account" "aws-load-balancer-controller-service-account" {
  metadata {
    name      = "aws-load-balancer-controller-service-account"
    namespace = "kube-system"
    labels    = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller-service-account"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.aws-load-balancer-controller-service-account
  ]

  set {
    name  = "region"
    value = "us-east-1"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller-service-account"
  }

  set {
    name  = "clusterName"
    value = var.eks_name
  }
}


#resource "kubernetes_ingress_v1" "dummy-ingress" {
#  metadata {
#    name = "dummy-ingress"
#    annotations = {
#      "ingress.kubernetes.io/ssl-redirect": "false"
#      # share a single ALB with all ingress rules with search-app-ingress
#      "alb.ingress.kubernetes.io/group.name": "senik"
#      # by default the alb is internal!!!:
#      "alb.ingress.kubernetes.io/scheme": "internet-facing"
#      "kubernetes.io/ingress.class": "alb"
#
#    }
#  }
##  wait_for_load_balancer = true
#  spec {
#    default_backend {
#      service {
#        name = "kubernetes"
#        port {
#          number = 80
#        }
#      }
#    }
#  }
#}
#
#resource "kubernetes_ingress_v1" "dummy-ingress2" {
#  metadata {
#    name = "dummy-ingress2"
#    annotations = {
#      "ingress.kubernetes.io/ssl-redirect": "false"
#      # share a single ALB with all ingress rules with search-app-ingress
#      "alb.ingress.kubernetes.io/group.name": "senik"
#      # by default the alb is internal!!!:
#      "alb.ingress.kubernetes.io/scheme": "internet-facing"
#      "kubernetes.io/ingress.class": "alb"
#
#    }
#  }
##  wait_for_load_balancer = true
#  spec {
#    default_backend {
#      service {
#        name = "kubernetes"
#        port {
#          number = 80
#        }
#      }
#    }
#  }
#}
