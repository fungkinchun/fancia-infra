module "prod" {
  source          = "./fancia"
  project_name    = var.project_name
  domain_name     = var.domain_name
  region          = var.region
  environment     = "prod"
  repositories    = var.repositories
  github_username = var.github_username
  github_token    = var.github_token
  vpc_cidr        = "10.0.0.0/16"
  az_count        = 2
  credentials     = var.credentials
  use_eks         = var.use_eks
}

module "dev" {
  source                 = "./fancia"
  project_name           = var.project_name
  domain_name            = var.domain_name
  region                 = var.region
  environment            = "dev"
  repositories           = var.repositories
  github_username        = var.github_username
  github_token           = var.github_token
  vpc_cidr               = "10.0.0.0/16"
  az_count               = 2
  credentials            = var.credentials
  use_eks                = var.use_eks
  vpc_id                 = module.prod.vpc_id
  private_subnet_ids     = module.prod.subnet_ids
  public_subnet_ids      = module.prod.public_subnet_ids
  database_subnet_ids    = module.prod.database_subnet_ids
  db_subnet_group_name   = module.prod.db_subnet_group_name
  public_hosted_zone_id  = module.prod.public_hosted_zone_id
  private_hosted_zone_id = module.prod.private_hosted_zone_id
  rds_secret_names = {
    for k, v in module.prod.rds_secret_name_map : k => v.databaseSecretName
  }
}

data "aws_caller_identity" "current" {}

output "prod" {
  value = {
    domain_name            = module.prod.domain_name
    email                  = var.email
    aws_account_id         = data.aws_caller_identity.current.account_id
    vpc_id                 = module.prod.vpc_id
    acm_certificate_arn    = module.prod.acm_certificate_arn
    private_hosted_zone_id = module.prod.private_hosted_zone_id
    public_hosted_zone_id  = module.prod.public_hosted_zone_id
    rds_secret_name_map    = module.prod.rds_secret_name_map
    credentials_name_map   = module.prod.credentials_name_map
    iam_access_key_id      = module.prod.iam_access_key_id
    iam_secret_access_key  = module.prod.iam_secret_access_key
    subnet_ids             = module.prod.subnet_ids
  }
  sensitive = true
}

output "dev" {
  value = {
    domain_name            = module.dev.domain_name
    email                  = var.email
    aws_account_id         = data.aws_caller_identity.current.account_id
    vpc_id                 = module.dev.vpc_id
    acm_certificate_arn    = module.dev.acm_certificate_arn
    private_hosted_zone_id = module.dev.private_hosted_zone_id
    public_hosted_zone_id  = module.dev.public_hosted_zone_id
    rds_secret_name_map    = module.dev.rds_secret_name_map
    credentials_name_map   = module.dev.credentials_name_map
    iam_access_key_id      = module.dev.iam_access_key_id
    iam_secret_access_key  = module.dev.iam_secret_access_key
    subnet_ids             = module.dev.subnet_ids
  }
  sensitive = true
}
