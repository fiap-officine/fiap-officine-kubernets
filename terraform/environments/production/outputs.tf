output "vpc_id" {
  description = "EKS, Security Groups, ALB, VPC Link"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "NAT Gateways e recursos públicos"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "EKS, pods, Internal ALB e VPC Link"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "RDS PostgreSQL"
  value       = module.vpc.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "RDS"
  value       = module.vpc.database_subnet_group_name
}

output "nat_gateway_ids" {
  description = "NAT Gateway"
  value       = module.vpc.nat_gateway_ids
}

output "availability_zones" {
  description = "Distribuição dos recursos"
  value       = module.vpc.availability_zones
}

output "vpc_cidr_block" {
  description = "Security Groups e regras internas"
  value       = module.vpc.vpc_cidr_block
}

output "alb_security_group_id" {
  description = "Security Group ID para o Internal ALB"
  value       = module.security_groups.alb_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "Security Group ID para os EKS worker nodes"
  value       = module.security_groups.eks_nodes_security_group_id
}

output "rds_security_group_id" {
  description = "Security Group ID para o RDS PostgreSQL"
  value       = module.security_groups.rds_security_group_id
}

# ── EKS Outputs ─────────────────────────────────
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security Group ID do cluster EKS (control plane)"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security Group ID dos worker nodes do EKS"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN do provedor OIDC para IRSA (AWS Load Balancer Controller)"
  value       = module.eks.oidc_provider_arn
}

output "cluster_certificate_authority_data" {
  description = "Certificate Authority data do cluster EKS"
  value       = module.eks.cluster_certificate_authority_data
}
