output "cluster_id" {
  description = "ID do cluster EKS"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN do cluster EKS"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Dados da Certificate Authority (CA) do cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security Group ID gerado automaticamente pelo EKS para o cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security Group ID associado aos nós do EKS"
  value       = var.node_security_group_id != "" ? var.node_security_group_id : aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN do provedor OIDC do cluster (usado para IRSA e AWS Load Balancer Controller)"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider" {
  description = "URL do provedor OIDC sem https:// (para condições de trust policy)"
  value       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

output "node_group_arn" {
  description = "ARN do Managed Node Group"
  value       = aws_eks_node_group.main.arn
}

output "node_role_arn" {
  description = "IAM Role ARN dos worker nodes"
  value       = aws_iam_role.node.arn
}
