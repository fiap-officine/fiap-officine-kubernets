output "vpc_id" {
  description = "VPC ID — Utilizado por EKS, Security Groups, ALB e VPC Link"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas — NAT Gateways e recursos públicos"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas — EKS, pods, Internal ALB e VPC Link"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "IDs das subnets de banco — RDS PostgreSQL"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Nome do DB Subnet Group — RDS PostgreSQL"
  value       = module.vpc.database_subnet_group_name
}

output "nat_gateway_ids" {
  description = "IDs dos NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "availability_zones" {
  description = "Zonas de disponibilidade — Distribuição dos recursos"
  value       = module.vpc.azs
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC — Security Groups e regras internas"
  value       = module.vpc.vpc_cidr_block
}
