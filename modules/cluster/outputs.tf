output "cluster_endpoint" {
  value = try(module.eks[0].cluster_endpoint, null)
}

output "cluster_ca_certificate" {
  value = try(module.eks[0].cluster_ca_certificate, null)
}

output "cluster_name" {
  value = try(module.eks[0].cluster_name, null)
}

output "pod_role_arn" {
  value = try(module.eks[0].pod_role_arn, null)
}
