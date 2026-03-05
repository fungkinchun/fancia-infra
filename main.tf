provider "aws" {
  region  = var.region
}

module "dev" {
  source               = "./environments/dev"
  project_name         = var.project_name
  region               = var.region
  environment          = "dev"
  repo_names           = var.repo_names
  github_username      = var.github_username
  github_token         = var.github_token
  vpc_cidr             = "10.0.0.0/16"
  az_count             = 2
  s3_credentials       = var.s3_credentials
  smtp_credentials     = var.smtp_credentials
}

output "dev_iam_access_key_id" {
  value     = module.dev.dev_iam_access_key_id
  sensitive = true
}

output "dev_iam_secret_access_key" {
  value     = module.dev.dev_iam_secret_access_key
  sensitive = true
}
