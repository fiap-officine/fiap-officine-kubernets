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
