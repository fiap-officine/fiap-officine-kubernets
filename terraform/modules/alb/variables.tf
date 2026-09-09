variable "name" {
  description = "Name prefix for all ALB resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB (private subnets for internal ALB)"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal (true for API Gateway -> VPC Link -> Internal ALB)"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "List of security group IDs to assign to the ALB. If empty, the module creates a default one."
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "target_port" {
  description = "Port on the target (EKS pods)"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS (leave empty for HTTP only)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
