variable "name" {
  description = "Name prefix for the API Gateway"
  type        = string
}

variable "description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "HTTP API Gateway for fiap-officine microservices"
}

variable "target_uri" {
  description = "Backend target URI to forward requests (e.g., http://<k3s_public_ip>:80)"
  type        = string
}

variable "cors_allow_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "List of allowed CORS HTTP methods"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"]
}

variable "cors_allow_headers" {
  description = "List of allowed CORS headers"
  type        = list(string)
  default     = ["content-type", "authorization", "x-amz-date", "x-api-key", "x-amz-security-token"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ── Lambda Auth Integration (Repo 1) ───────────
variable "auth_lambda_arn" {
  description = "ARN of the Auth Lambda function for /auth/* routes (from fiap-officine-auth-lambda repo)"
  type        = string
  default     = null
}

variable "auth_lambda_invoke_arn" {
  description = "Optional invocation ARN of the Auth Lambda (if not specified, derived automatically)"
  type        = string
  default     = null
}

# ── Authorizer Settings ─────────────────────────
variable "authorizer_lambda_arn" {
  description = "ARN of custom Lambda Authorizer function to validate JWT tokens on protected routes"
  type        = string
  default     = null
}

variable "authorizer_lambda_invoke_arn" {
  description = "Optional invocation ARN of the Lambda Authorizer"
  type        = string
  default     = null
}

variable "jwt_issuer" {
  description = "Issuer URL for native JWT Authorizer (e.g. Cognito, Auth0, Keycloak)"
  type        = string
  default     = null
}

variable "jwt_audience" {
  description = "List of allowed audiences for native JWT Authorizer"
  type        = list(string)
  default     = ["fiap-officine-api"]
}

