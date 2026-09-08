# ──────────────────────────────────────────────────────────────────────────────
# GitHub OIDC Identity Provider
# Registra o GitHub como provedor OIDC confiável na conta AWS.
# Só deve existir UMA vez por conta — use data source se já existir.
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint do certificado TLS do GitHub Actions OIDC
  # Valor fixo e público — válido desde 2023
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}

# Se o OIDC provider já existe na conta, use este data source no lugar do resource acima
# e defina create_oidc_provider = false na variável.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? (
    aws_iam_openid_connect_provider.github[0].arn
  ) : (
    data.aws_iam_openid_connect_provider.github[0].arn
  )
}

# ──────────────────────────────────────────────────────────────────────────────
# Trust Policy — quem pode assumir a role
# Restringe por organização/repositório/branch para evitar que qualquer
# repositório GitHub do mundo assuma sua role.
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # IMPORTANTE: GitHub org accounts incluem IDs numéricos no sub:
      # Formato pessoal: repo:org/repo:ref:refs/heads/main
      # Formato org:     repo:org@ID/repo@ID:ref:refs/heads/main
      #
      # Use sempre StringLike com wildcard para cobrir ambos os formatos.
      # Exemplos de values:
      #   "repo:my-org*/my-repo*:*"                       → qualquer branch (recomendado)
      #   "repo:my-org*/my-repo*:ref:refs/heads/main"     → apenas branch main
      #   "repo:my-org*/my-repo*:environment:production"  → apenas environment production
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.allowed_subjects
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# IAM Role assumida pelo GitHub Actions
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  description        = "Role assumed by GitHub Actions via OIDC for ${join(", ", var.allowed_subjects)}"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name = var.role_name
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# Políticas gerenciadas anexadas à role (ex: AdministratorAccess para CI/CD)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

# ──────────────────────────────────────────────────────────────────────────────
# Política inline customizada (permissões granulares para Terraform + EKS + ECR)
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "github_actions_inline" {
  # Terraform state backend
  statement {
    sid    = "TerraformS3State"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*",
    ]
  }

  statement {
    sid    = "TerraformDynamoDBLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.tf_lock_table}",
    ]
  }

  # ECR — push/pull de imagens
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
    ]
    resources = ["*"]
  }

  # EKS — deploy de workloads
  statement {
    sid    = "EKSAccess"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_inline" {
  name   = "${var.role_name}-inline"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_inline.json
}
