terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend remoto — descomente após criar o bucket via bootstrap
  # backend "s3" {
  #   bucket         = "fiap-officine-terraform-state"
  #   key            = "homolog/terraform.tfstate"
  #   region         = "sa-east-1"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "homolog"
  project     = "fiap-officine"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# ──────────────────────────────────────────────
# VPC (100% Free Tier: sem NAT Gateway)
# ──────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  name = "${local.project}-${local.environment}"
  cidr = var.vpc_cidr

  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets

  # Free Tier: NAT Gateway desabilitado ($0 custo)
  # Instâncias na public subnet usam Internet Gateway direto
  enable_nat_gateway = var.enable_nat_gateway

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# Security Groups (ALB, EKS/K3s, RDS)
# ──────────────────────────────────────────────
module "security_groups" {
  source = "../../modules/security_groups"

  name     = "${local.project}-${local.environment}"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# Kubernetes Free Tier: K3s Node (t3.micro, $0 custo)
# ──────────────────────────────────────────────
module "k3s" {
  source = "../../modules/k3s"

  name      = "${local.project}-${local.environment}"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0] # Subnet pública para acesso direto via IGW sem custo de NAT

  instance_type = var.instance_type # t3.micro (Free Tier)
  disk_size     = 20                # 20 GiB gp3 (Free Tier permite até 30 GiB)

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# API Gateway (HTTP API v2 - 100% Free Tier, $0 custo)
# ──────────────────────────────────────────────
module "api_gateway" {
  source = "../../modules/api_gateway"

  name        = "${local.project}-${local.environment}"
  description = "HTTP API Gateway for ${local.project} (${local.environment})"
  target_uri  = "http://${module.k3s.public_ip}:80"

  auth_lambda_arn       = var.auth_lambda_arn
  authorizer_lambda_arn = var.authorizer_lambda_arn

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# EKS Cluster Gerenciado (Descomente quando desejar subir o EKS pago da AWS)
# ──────────────────────────────────────────────
# module "eks" {
#   source = "../../modules/eks"
# 
#   cluster_name       = "${local.project}-${local.environment}"
#   kubernetes_version = var.kubernetes_version
# 
#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnet_ids
# 
#   endpoint_public_access  = true
#   endpoint_private_access = true
# 
#   node_security_group_id = module.security_groups.eks_nodes_security_group_id
# 
#   instance_types = var.eks_instance_types
#   desired_size   = var.eks_desired_size
#   min_size       = var.eks_min_size
#   max_size       = var.eks_max_size
# 
#   tags = local.common_tags
# }
