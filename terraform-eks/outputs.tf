output "region" {
  description = "AWS region"
  value       = module.eks.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "private_key" {
  sensitive = true
  value     = module.certificate.private_key
}
