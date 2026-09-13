# ──────────────────────────────────────────────
# AWS API Gateway (HTTP API v2) - 100% Free Tier
# ──────────────────────────────────────────────

data "aws_region" "current" {}

locals {
  has_lambda_authorizer = var.authorizer_lambda_arn != null
  has_jwt_authorizer    = var.jwt_issuer != null
  has_authorizer        = local.has_lambda_authorizer || local.has_jwt_authorizer

  authorizer_type = local.has_jwt_authorizer ? "JWT" : (local.has_lambda_authorizer ? "CUSTOM" : "NONE")
  authorizer_id   = local.has_jwt_authorizer ? try(aws_apigatewayv2_authorizer.jwt[0].id, null) : (local.has_lambda_authorizer ? try(aws_apigatewayv2_authorizer.lambda[0].id, null) : null)

  auth_lambda_uri = var.auth_lambda_invoke_arn != null ? var.auth_lambda_invoke_arn : (
    var.auth_lambda_arn != null ? "arn:aws:apigateway:${data.aws_region.current.region}:lambda:path/2015-03-31/functions/${var.auth_lambda_arn}/invocations" : null
  )

  authorizer_lambda_uri = var.authorizer_lambda_invoke_arn != null ? var.authorizer_lambda_invoke_arn : (
    var.authorizer_lambda_arn != null ? "arn:aws:apigateway:${data.aws_region.current.region}:lambda:path/2015-03-31/functions/${var.authorizer_lambda_arn}/invocations" : null
  )
}

# ── API Gateway Core ────────────────────────────
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.name}-http-api"
  protocol_type = "HTTP"
  description   = var.description

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = var.cors_allow_methods
    allow_headers = var.cors_allow_headers
    max_age       = 300
  }

  tags = merge(var.tags, {
    Name = "${var.name}-http-api"
  })
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = var.tags
}

# ── Backend Integration (Kubernetes Microservices)
resource "aws_apigatewayv2_integration" "backend" {
  api_id               = aws_apigatewayv2_api.main.id
  integration_type     = "HTTP_PROXY"
  integration_method   = "ANY"
  integration_uri      = var.target_uri
  connection_type      = "INTERNET"
  passthrough_behavior = "WHEN_NO_MATCH"
}

# ── Auth Lambda Integration (Serverless Function)
resource "aws_apigatewayv2_integration" "auth_lambda" {
  count                  = var.auth_lambda_arn != null ? 1 : 0
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.auth_lambda_uri
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "api_gateway_auth" {
  count         = var.auth_lambda_arn != null ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ── Authorizers (JWT or Custom Lambda) ───────────
resource "aws_apigatewayv2_authorizer" "lambda" {
  count                             = var.authorizer_lambda_arn != null ? 1 : 0
  api_id                            = aws_apigatewayv2_api.main.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = local.authorizer_lambda_uri
  name                              = "${var.name}-lambda-authorizer"
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_result_ttl_in_seconds  = 300
}

resource "aws_lambda_permission" "api_gateway_authorizer" {
  count         = var.authorizer_lambda_arn != null ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count            = var.jwt_issuer != null ? 1 : 0
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.name}-jwt-authorizer"

  jwt_configuration {
    audience = var.jwt_audience
    issuer   = var.jwt_issuer
  }
}

# ── Rota Pública: Auth / Login ──────────────────
resource "aws_apigatewayv2_route" "auth_login" {
  count              = var.auth_lambda_arn != null ? 1 : 0
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /auth/login"
  target             = "integrations/${aws_apigatewayv2_integration.auth_lambda[0].id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "auth_proxy" {
  count              = var.auth_lambda_arn != null ? 1 : 0
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /auth/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.auth_lambda[0].id}"
  authorization_type = "NONE"
}

# ── Rotas Públicas: Visualização, Docs & Observabilidade ────
resource "aws_apigatewayv2_route" "health" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /health"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "health_api" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /api/v1/health"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "docs" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /docs"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "openapi" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /openapi.json"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "redoc" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /redoc"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "NONE"
}

# ── Rota Principal (Protegida por Authorizer se configurado)
resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = local.authorizer_type
  authorizer_id      = local.authorizer_id
}

