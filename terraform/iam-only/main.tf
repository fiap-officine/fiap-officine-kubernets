##
## iam-only/main.tf
##
## Cria APENAS o OIDC Provider + IAM Role para o GitHub Actions.
## Use para testar a autenticação OIDC sem subir nenhuma outra infra.
##
## Permissões necessárias no IAM user local:
##   - iam:CreateOpenIDConnectProvider
##   - iam:CreateRole
##   - iam:PutRolePolicy
##   - iam:GetRole / iam:GetRolePolicy
##
## Como usar:
##   cd terraform/iam-only
##   terraform init
##   terraform apply
##   → copie o output role_arn para o secret AWS_ROLE_ARN no GitHub
##

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # state local — ok para este teste
}

provider "aws" {
  region = "sa-east-1"
}

locals {
  github_org  = "fiap-officine"
  github_repo = "fiap-officine-kubernets"
}

# ── OIDC Provider ──────────────────────────────
# O provider já existe na conta (criado em apply anterior).
# Usamos data source para referenciar sem tentar recriar.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ── Trust policy ───────────────────────────────
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # GitHub inclui IDs numéricos no sub: repo:org@ID/repo@ID:ref
      # Exemplo real: repo:fiap-officine@326213145/fiap-officine-kubernets@1360599486:ref:refs/heads/main
      # O wildcard * cobre tanto o formato antigo quanto o novo com IDs numéricos.
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_org}*/${local.github_repo}*:*"]
    }
  }
}

# ── IAM Role ───────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name               = "fiap-officine-github-actions"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

# Permissão mínima para o teste: apenas sts:GetCallerIdentity
resource "aws_iam_role_policy" "test" {
  name = "test-caller-identity"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sts:GetCallerIdentity"]
      Resource = "*"
    }]
  })
}

# ── Output ─────────────────────────────────────
output "role_arn" {
  description = "Cole este valor no secret AWS_ROLE_ARN do GitHub"
  value       = aws_iam_role.github_actions.arn
}
