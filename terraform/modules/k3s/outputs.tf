output "instance_id" {
  description = "EC2 Instance ID do nó K3s"
  value       = aws_instance.k3s.id
}

output "public_ip" {
  description = "IP público da instância K3s"
  value       = aws_instance.k3s.public_ip
}

output "private_ip" {
  description = "IP privado da instância K3s na VPC"
  value       = aws_instance.k3s.private_ip
}

output "security_group_id" {
  description = "Security Group ID do nó K3s"
  value       = aws_security_group.k3s.id
}

output "kubernetes_api_endpoint" {
  description = "URL do Kubernetes API Server"
  value       = "https://${aws_instance.k3s.public_ip}:6443"
}

data "aws_region" "current" {}

output "ssm_connect_command" {
  description = "Comando para conectar ao terminal do nó via AWS SSM sem necessidade de SSH"
  value       = "aws ssm start-session --target ${aws_instance.k3s.id} --region ${data.aws_region.current.region}"
}
