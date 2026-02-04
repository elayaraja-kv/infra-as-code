output "cluster_id" {
  description = "Cluster ID"
  value       = module.gke.cluster_id
}

output "name" {
  description = "Cluster name"
  value       = module.gke.name
}

output "location" {
  description = "Cluster location"
  value       = module.gke.location
}

output "endpoint" {
  description = "Cluster endpoint"
  value       = module.gke.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "Cluster CA certificate (base64)"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "master_version" {
  description = "Current master Kubernetes version"
  value       = module.gke.master_version
}

output "service_account" {
  description = "Service account used by the node pools"
  value       = module.gke.service_account
}

output "node_pools_names" {
  description = "List of node pool names"
  value       = module.gke.node_pools_names
}

output "master_ipv4_cidr_block" {
  description = "Master CIDR block"
  value       = module.gke.master_ipv4_cidr_block
}

output "peering_name" {
  description = "VPC peering name to Google network"
  value       = module.gke.peering_name
}

output "release_channel" {
  description = "Release channel of the cluster"
  value       = module.gke.release_channel
}
