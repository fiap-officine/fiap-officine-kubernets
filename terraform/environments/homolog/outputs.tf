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
  description = "NAT Gateway IDs (vazio em Free Tier)"
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

output "lambda_security_group_id" {
  description = "Security Group ID para a Function Serverless de Autenticação (Lambda)"
  value       = module.security_groups.lambda_security_group_id
}

# ── K3s Free Tier Outputs ───────────────────────
output "k3s_instance_id" {
  description = "EC2 Instance ID do nó K3s"
  value       = module.k3s.instance_id
}

output "k3s_public_ip" {
  description = "IP público da instância K3s para acessar a aplicação e API"
  value       = module.k3s.public_ip
}

output "k3s_api_endpoint" {
  description = "Endpoint da API do Kubernetes K3s"
  value       = module.k3s.kubernetes_api_endpoint
}

output "k3s_ssm_connect_command" {
  description = "Comando AWS CLI para conectar diretamente ao terminal da máquina sem SSH"
  value       = module.k3s.ssm_connect_command
}

# ── API Gateway Outputs ─────────────────────────
output "api_gateway_id" {
  description = "ID do API Gateway HTTP"
  value       = module.api_gateway.api_id
}

output "api_gateway_endpoint" {
  description = "URL pública de entrada do API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "auth_login_url" {
  description = "Endpoint de login para autenticação via CPF (POST /auth/login)"
  value       = module.api_gateway.auth_login_url
}

output "health_url" {
  description = "Endpoint público para monitoramento e healthchecks (GET /health)"
  value       = module.api_gateway.health_url
}

