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

  # State remoto no S3 (configuração parcial). O workflow terraform.yml cria o
  # bucket fiap-officine-tfstate-<account_id> se não existir e passa
  # bucket/key/region no init. Uso local sem AWS: terraform init -backend=false
  backend "s3" {
    encrypt = true
  }
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

  # Valores publicados no SSM e lidos pelos outros repositórios (database,
  # microsserviços, lambda): sem copiar IDs/URLs à mão entre pipelines
  ssm_prefix = "/${local.project}/${local.environment}"

  # Funções do repositório fiap-officine-lambda (ligadas ao API Gateway quando existem)
  auth_lambda_name       = "${local.project}-${local.environment}-auth-lambda"
  authorizer_lambda_name = "${local.project}-${local.environment}-lambda-authorizer"
  lambda_arns            = zipmap(data.aws_lambda_functions.all.function_names, data.aws_lambda_functions.all.function_arns)
}

data "aws_lambda_functions" "all" {}

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

  # Pods do K3s acessam o RDS. A regra fica inline no SG do RDS: uma
  # aws_security_group_rule separada seria apagada a cada apply.
  rds_allowed_security_group_ids = [module.k3s.security_group_id]

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

  instance_type = var.instance_type # t3.medium (4 GiB)
  disk_size     = 20                # 20 GiB gp3 (Free Tier permite até 30 GiB)

  # O nó publica o kubeconfig em <ssm_prefix>/k3s/kubeconfig
  ssm_parameter_prefix = local.ssm_prefix

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# ECR: um repositório por microsserviço (imagens com tag = SHA do commit)
# ──────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "fiap-officine-os-service",
    "fiap-officine-billing-service",
    "fiap-officine-execution-service",
  ]
  max_image_count = 15

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

  # Ligadas automaticamente depois que o fiap-officine-lambda publica as funções
  # (basta rodar o workflow deste repositório de novo)
  auth_lambda_arn       = var.auth_lambda_arn != null ? var.auth_lambda_arn : lookup(local.lambda_arns, local.auth_lambda_name, null)
  authorizer_lambda_arn = var.authorizer_lambda_arn != null ? var.authorizer_lambda_arn : lookup(local.lambda_arns, local.authorizer_lambda_name, null)

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# Parâmetros compartilhados (SSM Parameter Store, gratuito)
# ──────────────────────────────────────────────
resource "aws_ssm_parameter" "shared" {
  for_each = {
    "api-gateway/url"          = module.api_gateway.api_endpoint
    "k3s/node-role-name"       = module.k3s.node_role_name
    "k3s/public-ip"            = module.k3s.public_ip
    "network/vpc-id"           = module.vpc.vpc_id
    "rds/security-group-id"    = module.security_groups.rds_security_group_id
    "rds/db-subnet-group-name" = module.vpc.database_subnet_group_name
    "lambda/security-group-id" = module.security_groups.lambda_security_group_id
  }

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
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
