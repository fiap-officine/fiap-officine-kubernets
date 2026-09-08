variable "name" {
  description = "Prefix name for the security groups"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block allowed to communicate with the ALB (from VPC Link / API Gateway)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all security groups"
  type        = map(string)
  default     = {}
}
