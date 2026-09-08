module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.2"

  name = var.name
  cidr = var.cidr

  azs              = var.availability_zones
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  # NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet group para RDS (cria o aws_db_subnet_group automaticamente)
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # Tags necessárias para o ALB Controller e Cluster Autoscaler do EKS
  public_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/elb" = "1"
  })

  private_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/internal-elb" = "1"
  })

  tags = var.tags
}
