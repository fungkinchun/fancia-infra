data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  public_subnets   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  database_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 20)]

  enable_nat_gateway     = !var.use_fck_nat
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_route_table = true
  create_database_subnet_group       = true

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

resource "aws_eip" "fck_nat" {
  count  = var.use_fck_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-fck-nat"
  }
}

module "fck_nat" {
  count   = var.use_fck_nat ? 1 : 0
  source  = "RaJiska/fck-nat/aws"
  version = "1.6.1"

  name          = "${var.project_name}-fck-nat"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = "t4g.nano"
  ha_mode       = true

  eip_allocation_ids = [aws_eip.fck_nat[0].allocation_id]

  update_route_tables = true
  route_tables_ids = {
    for i, id in module.vpc.private_route_table_ids : "private-${i}" => id
  }

  depends_on = [module.vpc]
}

output "vpc" {
  value = module.vpc
}

output "vpc_id" {
  value = module.vpc.vpc_id
}