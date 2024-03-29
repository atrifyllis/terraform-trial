module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.23"

  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    #     this causes problems with duplicate tags
    #    attach_cluster_primary_security_group = true

    # Disabling and using externally provided security groups
    create_security_group = false
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types           = ["t3.small"]
      capacity_type            = "SPOT"
      spot_allocation_strategy = "capacity-optimized"

      min_size     = 2
      max_size     = 2
      desired_size = 2

      pre_bootstrap_user_data = <<-EOT
      echo 'foo bar'
      EOT

      vpc_security_group_ids = [
        var.security_group_id
      ]
    }

    #    two = {
    #      name = "node-group-2"
    #
    #      instance_types = ["t3.medium"]
    #
    #      min_size     = 1
    #      max_size     = 2
    #      desired_size = 1
    #
    #      pre_bootstrap_user_data = <<-EOT
    #      echo 'foo bar'
    #      EOT
    #
    #      vpc_security_group_ids = [
    #        aws_security_group.node_group_two.id
    #      ]
    #    }
  }
}

locals {
  cluster_name = "eks-1"
}
