##
## bootstrap/main.tf
##
## Este entrypoint configura os pré-requisitos da conta AWS:
##   1. OIDC provider do GitHub
##   2. IAM Role assumida pelo GitHub Actions
##   3. S3 bucket + DynamoDB para o Terraform remote state
##
## Como usar:
##   cd terraform/bootstrap
##   terraform init
##   terraform apply
##
## ATENÇÃO: rode com credenciais AWS locais (IAM user/SSO) — uma única vez.
## Após isso, o GitHub Actions assume a role criada aqui.
##

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap NÃO usa backend remoto — o state fica local.
  # Faça commit do terraform.tfstate do bootstrap ou guarde em lugar seguro.
}

provider "aws" {
  region = "sa-east-1"

  default_tags {
    tags = {
      Project     = "fiap-officine"
      ManagedBy   = "terraform"
      Component   = "bootstrap"
    }
  }
}

locals {
  project        = "fiap-officine"
  github_org     = "fiap-officine"                       # ← sua org/usuário no GitHub
  github_repo    = "fiap-officine-kubernets"             # ← nome do repositório
  tf_state_bucket = "${local.project}-terraform-state"
  tf_lock_table   = "${local.project}-terraform-lock"
}

# ──────────────────────────────────────────────
# S3 bucket para Terraform remote state
# ──────────────────────────────────────────────
resource "aws_s3_bucket" "tf_state" {
  bucket = local.tf_state_bucket

  tags = {
    Name = local.tf_state_bucket
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────────
# DynamoDB para state locking
# ──────────────────────────────────────────────
resource "aws_dynamodb_table" "tf_lock" {
  name         = local.tf_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = local.tf_lock_table
  }
}

# ──────────────────────────────────────────────
# GitHub OIDC + IAM Role
# ──────────────────────────────────────────────
module "github_oidc" {
  source = "../modules/github_oidc"

  role_name            = "${local.project}-github-actions"
  create_oidc_provider = true

  # Wildcard cobre contas pessoais E de organização (que incluem @ID numérico no sub)
  # Formato org: repo:fiap-officine@326213145/fiap-officine-kubernets@1360599486:...
  allowed_subjects = [
    "repo:${local.github_org}*/${local.github_repo}*:*",
  ]
  allow_all_branches = true

  # Permissões mínimas para Terraform + ECR + EKS
  managed_policy_arns = []  # adicione ARNs se necessário, ex: AdministratorAccess

  tf_state_bucket = local.tf_state_bucket
  tf_lock_table   = local.tf_lock_table

  tags = {
    Project   = local.project
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# Outputs — copie o role_arn para o secret do GitHub
# ──────────────────────────────────────────────
output "github_actions_role_arn" {
  description = "Copie este valor para o secret AWS_ROLE_ARN no GitHub"
  value       = module.github_oidc.role_arn
}

output "tf_state_bucket" {
  value = aws_s3_bucket.tf_state.bucket
}

output "tf_lock_table" {
  value = aws_dynamodb_table.tf_lock.name
}
