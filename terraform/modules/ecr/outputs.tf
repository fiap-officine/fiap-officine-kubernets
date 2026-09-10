output "repository_urls" {
  description = "Map of repository name to URL"
  value       = { for name, repo in aws_ecr_repository.main : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map of repository name to ARN"
  value       = { for name, repo in aws_ecr_repository.main : name => repo.arn }
}

output "registry_id" {
  description = "Registry ID (AWS account ID)"
  value       = try(values(aws_ecr_repository.main)[0].registry_id, null)
}
