variable "role_name" {
  description = "Name of the IAM role to be assumed by GitHub Actions"
  type        = string
  default     = "github-actions-role"
}

variable "create_oidc_provider" {
  description = <<-EOT
    Set to true to create the GitHub OIDC provider in this AWS account.
    Set to false if the provider already exists (only one per account is allowed).
    Use: aws iam list-open-id-connect-providers to check.
  EOT
  type        = bool
  default     = true
}

variable "allowed_subjects" {
  description = <<-EOT
    List of OIDC subjects (GitHub repos/branches) allowed to assume this role.
    Examples:
      - "repo:my-org/my-repo:*"                            → any branch/tag in the repo
      - "repo:my-org/my-repo:ref:refs/heads/main"          → only main branch
      - "repo:my-org/my-repo:environment:production"       → only production environment
  EOT
  type        = list(string)
}

variable "allow_all_branches" {
  description = "If true, uses StringLike condition (allows wildcards in allowed_subjects). If false, uses StringEquals (exact match)."
  type        = bool
  default     = true
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the GitHub Actions role"
  type        = list(string)
  default     = []
}

variable "tf_state_bucket" {
  description = "Name of the S3 bucket used for Terraform remote state (inline policy)"
  type        = string
}

variable "tf_lock_table" {
  description = "Name of the DynamoDB table used for Terraform state locking (inline policy)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
