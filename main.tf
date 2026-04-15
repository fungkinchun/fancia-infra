
module "dev" {
  source          = "./fancia"
  project_name    = var.project_name
  domain_name     = var.domain_name
  region          = var.region
  environment     = "dev"
  repositories      = var.repositories
  github_username = var.github_username
  github_token    = var.github_token
  vpc_cidr        = "10.0.0.0/16"
  az_count        = 2
  credentials     = var.credentials
}

data "aws_caller_identity" "current" {}

output "dev" {
  value = {
    domain_name           = var.domain_name
    email                 = var.email
    aws_account_id        = data.aws_caller_identity.current.account_id
    vpc_id                = module.dev.vpc_id
    acm_certificate_arn   = module.dev.acm_certificate_arn
    hosted_zone_id        = module.dev.hosted_zone_id
    rds_secret_name_map   = module.dev.rds_secret_name_map
    credentials_name_map  = module.dev.credentials_name_map
    iam_access_key_id     = module.dev.iam_access_key_id
    iam_secret_access_key = module.dev.iam_secret_access_key
  }
  sensitive = true
}
