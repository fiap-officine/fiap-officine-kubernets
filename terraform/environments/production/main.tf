terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend remoto — descomente após criar o bucket via bootstrap
  # backend "s3" {
  #   bucket         = "fiap-officine-terraform-state"
  #   key            = "production/terraform.tfstate"
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
  environment = "production"
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

  name = "${local.project}-${local.environment}"
  cidr = var.vpc_cidr

  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets

  # Production: 1 NAT Gateway por AZ para alta disponibilidade
  single_nat_gateway = false

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# Security Groups (ALB, EKS, RDS)
# ──────────────────────────────────────────────
module "security_groups" {
  source = "../../modules/security_groups"

  name     = "${local.project}-${local.environment}"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr

  tags = local.common_tags
}
