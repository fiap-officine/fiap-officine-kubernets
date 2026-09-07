terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "fiap-officine-terraform-state"
    key            = "homolog/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "fiap-officine-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "sa-east-1"

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
# VPC
# ──────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  name       = "${local.project}-${local.environment}"
  cidr_block = "10.1.0.0/16"

  availability_zones   = ["sa-east-1a", "sa-east-1b"]
  public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# ECR
# ──────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  repository_names = ["fiap-officine-api", "fiap-officine-worker"]
  scan_on_push     = true
  max_image_count  = 10

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# EKS
# ──────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name           = "${local.project}-${local.environment}"
  kubernetes_version     = "1.30"
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_subnet_ids     = module.vpc.private_subnet_ids
  endpoint_public_access = true

  instance_types = ["t3.medium"]
  desired_size   = 1
  min_size       = 1
  max_size       = 2

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# ALB
# ──────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  name       = "${local.project}-${local.environment}"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids

  internal                   = false
  enable_deletion_protection = false
  health_check_path          = "/health"

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# API Gateway
# ──────────────────────────────────────────────
module "api_gateway" {
  source = "../../modules/api_gateway"

  api_name        = "${local.project}-${local.environment}"
  api_description = "API Gateway for ${local.project} - ${local.environment}"
  stage_name      = local.environment
  alb_dns_name    = module.alb.alb_dns_name

  tags = local.common_tags
}
