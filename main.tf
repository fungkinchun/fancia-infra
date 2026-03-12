
module "dev" {
  source           = "./environments/dev"
  project_name     = var.project_name
  domain_name      = var.domain_name
  region           = var.region
  environment      = "dev"
  repo_names       = var.repo_names
  github_username  = var.github_username
  github_token     = var.github_token
  vpc_cidr         = "10.0.0.0/16"
  az_count         = 2
  s3_credentials   = var.s3_credentials
  smtp_credentials = var.smtp_credentials
}

data "aws_caller_identity" "dev_current" {}

output "dev_iam_access_key_id" {
  value     = module.dev.dev_iam_access_key_id
  sensitive = true
}

output "dev_iam_secret_access_key" {
  value     = module.dev.dev_iam_secret_access_key
  sensitive = true
}

output "dev_rds_secret_name_map" {
  value     = module.dev.rds_secret_name_map
  sensitive = true
}

output "dev_aws_account_id" {
  value = data.aws_caller_identity.dev_current.account_id
}

output "domain_name" {
  value = var.domain_name
}

output "dev_vpc_id" {
  value = module.dev.vpc_id
}

output "dev_private_ca_arn" {
  value = module.dev.private_ca_arn
}

output "dev_acm_certificate_arn" {
  value = module.dev.acm_certificate_arn
}
