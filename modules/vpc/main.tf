data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)] # 10.0.10.0/24, 10.0.11.0/24, ...
  public_subnets   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]  # 10.0.1.0/24, 10.0.2.0/24, ...
  database_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 20)] # 10.0.20.0/24, 10.0.21.0/24, ...

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_route_table = true
  create_database_subnet_group       = true

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }

  public_subnet_tags = {
    Tier                     = "public"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    Tier = "private-app"
  }

  database_subnet_tags = {
    Tier = "private-db"
  }
}

output "vpc" {
  value = module.vpc
}

output "vpc_id" {
  value = module.vpc.vpc_id
}