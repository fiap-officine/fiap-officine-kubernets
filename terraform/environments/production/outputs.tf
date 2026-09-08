output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes)"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs (RDS)"
  value       = module.vpc.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "RDS subnet group name"
  value       = module.vpc.database_subnet_group_name
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (3 in production, one per AZ)"
  value       = module.vpc.nat_gateway_ids
}

output "availability_zones" {
  description = "Availability zones"
  value       = module.vpc.availability_zones
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "alb_security_group_id" {
  description = "Security Group ID for the ALB"
  value       = module.security_groups.alb_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "Security Group ID for EKS nodes"
  value       = module.security_groups.eks_nodes_security_group_id
}

output "rds_security_group_id" {
  description = "Security Group ID for RDS PostgreSQL"
  value       = module.security_groups.rds_security_group_id
}
