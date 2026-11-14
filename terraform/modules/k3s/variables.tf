variable "name" {
  description = "Name prefix for the K3s node and related resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the node will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the node will be placed (must be a public subnet for direct internet access without NAT Gateway)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID para o nó K3s (null = Ubuntu 24.04 LTS x86_64 mais recente da Canonical na região)"
  type        = string
  default     = null
}

variable "ssm_parameter_prefix" {
  description = "Prefixo no SSM Parameter Store onde o nó publica o kubeconfig (ex.: /fiap-officine/homolog)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (Free Tier eligible: t3.micro or t2.micro)"
  type        = string
  default     = "t3.micro"
}

variable "disk_size" {
  description = "Size of the root EBS volume in GiB (Free Tier allows up to 30 GiB)"
  type        = number
  default     = 20
}

variable "allowed_k8s_api_cidrs" {
  description = "CIDR blocks allowed to access the Kubernetes API on port 6443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "key_name" {
  description = "Optional EC2 Key Pair name for SSH access (optional, SSM Session Manager is enabled by default)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
