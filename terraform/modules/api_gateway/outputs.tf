output "api_id" {
  description = "ID do API Gateway HTTP"
  value       = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  description = "URL pública de acesso ao API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_arn" {
  description = "ARN do API Gateway HTTP"
  value       = aws_apigatewayv2_api.main.arn
}

output "stage_id" {
  description = "ID do Stage default"
  value       = aws_apigatewayv2_stage.default.id
}

output "auth_login_url" {
  description = "URL para autenticação via CPF (POST /auth/login)"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/auth/login"
}

output "health_url" {
  description = "URL para healthcheck e observabilidade pública (GET /health)"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/health"
}

output "authorizer_id" {
  description = "ID do Authorizer ativo (JWT ou Custom Lambda), se configurado"
  value       = local.authorizer_id
}
