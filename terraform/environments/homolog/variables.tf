variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway (false = $0 custo no Free Tier)"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Tipo de instância EC2 para o K3s (t3.micro é elegível para o Free Tier)"
  type        = string
  default     = "t3.micro"
}

variable "public_subnets" {
  description = "Public subnet CIDRs (ALB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs (EKS nodes)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnets" {
  description = "Database subnet CIDRs (RDS PostgreSQL)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

# ── EKS Settings ────────────────────────────────
variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_instance_types" {
  description = "Instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

# ── Serverless Auth Lambda Settings (Repo 1) ───
variable "auth_lambda_arn" {
  description = "ARN da Lambda de autenticação por CPF (fiap-officine-auth-lambda)"
  type        = string
  default     = null
}

variable "authorizer_lambda_arn" {
  description = "ARN da Lambda authorizer para validação de JWT"
  type        = string
  default     = null
}

