output "eks" {
  description = "EKS cluster"
  value       = module.eks
}

output "eks_node_subnets" {
  description = "EKS Node Subnets"
  value       = module.eks_node_subnets
}

output "eks_node_subnet_cidr" {
  description = "EKS Node Subnet CIDR"
  value       = local.ipv4_cidr_block
}

output "eks_cp_subnets" {
  description = "EKS Control Panel Subnets"
  value       = module.eks_node_subnets
}

output "eks_cp_subnet_cidr" {
  description = "EKS Control Panel Subnet CIDR"
  value       = local.ipv4_cidr_intra_subnets_block
}