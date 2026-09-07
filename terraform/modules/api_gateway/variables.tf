variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
}

variable "api_description" {
  description = "Description of the API Gateway REST API"
  type        = string
  default     = ""
}

variable "endpoint_type" {
  description = "API Gateway endpoint type (REGIONAL, EDGE, or PRIVATE)"
  type        = string
  default     = "REGIONAL"
}

variable "stage_name" {
  description = "Name of the API Gateway deployment stage"
  type        = string
  default     = "v1"
}

variable "alb_dns_name" {
  description = "DNS name of the ALB to proxy requests to"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
