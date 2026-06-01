provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Terraform   = "true"
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Terraform   = "true"
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

module "iam" {
  source       = "../modules/iam"
  region       = var.region
  account_name = "${var.project_name}-${var.environment}-user"
}

module "s3_artifacts" {
  source       = "../modules/s3"
  bucket_name  = "${var.project_name}-${var.environment}-backend-artifacts"
  environment  = var.environment
  project_name = var.project_name
  region       = var.region
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "codebuild.amazonaws.com",
        "codeartifact.amazonaws.com",
        "codepipeline.amazonaws.com",
        "codestar.amazonaws.com",
        "s3.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    actions = [
      "codeartifact:GetAuthorizationToken",
      "codeartifact:PublishPackageVersion",
      "codeartifact:PutPackageMetadata",
      "codeartifact:ReadFromRepository"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "sts:GetServiceBearerToken"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"
      values   = ["codeartifact.amazonaws.com"]
    }
  }
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "codepipeline:StartPipelineExecution",
      "codepipeline:GetPipelineExecution"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:CreateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:TagResource"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:PublishVersion",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionConfiguration",
      "lambda:UpdateAlias",
      "lambda:GetAlias",
      "lambda:CreateAlias",
      "lambda:DeleteAlias"
    ]
    resources = ["*"]
  }
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_codeartifact_domain" "codeartifact_domain" {
  domain = "${var.project_name}-${var.environment}"
}

module "developertools" {
  source = "../modules/developertools"
  for_each = {
    for repo in var.repositories : repo.name => repo
  }
  project_name            = var.project_name
  environment             = var.environment
  repo_name               = each.key
  codestar_connection_arn = aws_codestarconnections_connection.github.arn
  codebuild_role_arn      = aws_iam_role.codebuild_role.arn
  github_username         = var.github_username
  github_token            = var.github_token
  use_eks                 = var.use_eks
  depends_on              = [aws_codeartifact_domain.codeartifact_domain]
}

module "vpc" {
  source       = "../modules/vpc"
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 2
  environment  = var.environment
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = module.vpc.vpc.public_subnets
}

resource "aws_route53_zone" "private" {
  name = var.domain_name
  vpc {
    vpc_id = module.vpc.vpc.vpc_id
  }
}

resource "aws_route53_zone" "public" {
  name          = var.domain_name
  force_destroy = true
}

resource "aws_acm_certificate" "cdn" {
  provider          = aws.us_east_1
  domain_name       = "cdn.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cdn_cert_validation" {
  for_each = {
    for o in aws_acm_certificate.cdn.domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      record = o.resource_record_value
      type   = o.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.public.zone_id
}

resource "aws_acm_certificate_validation" "cdn" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cdn.arn
  validation_record_fqdns = [for record in aws_route53_record.cdn_cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

module "s3" {
  source       = "../modules/s3"
  bucket_name  = "${var.project_name}-${var.environment}-bucket"
  environment  = var.environment
  project_name = var.project_name
  region       = var.region

  depends_on = [aws_acm_certificate_validation.cdn]
}

resource "aws_s3_bucket_cors_configuration" "app_bucket" {
  bucket = module.s3.bucket_id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = [
      "http://localhost:3000",
      "https://fancia.co.uk",
      "https://www.fancia.co.uk",
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "cdn"
  type    = "A"

  alias {
    name                   = "cdn.${var.domain_name}"
    zone_id                = aws_route53_zone.public.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_ipv6" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "cdn"
  type    = "AAAA"

  alias {
    name                   = "cdn.${var.domain_name}"
    zone_id                = aws_route53_zone.public.zone_id
    evaluate_target_health = false
  }
}

module "rds" {
  source = "../modules/rds"
  for_each = {
    for repo in var.repositories : repo.name => repo
    if repo.is_service && repo.override_with_shared_rds == null
  }
  project_name         = var.project_name
  repo_name            = each.key
  environment          = var.environment
  zone_id              = aws_route53_zone.private.zone_id
  rds_id               = "${var.environment}-${each.key}"
  db_name              = var.project_name
  username             = var.username
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  vpc_id               = module.vpc.vpc.vpc_id
  private_subnet_ids   = module.vpc.vpc.database_subnets
  allowed_cidr_blocks  = [module.vpc.vpc.vpc_cidr_block]
  db_subnet_group_name = aws_db_subnet_group.main.name
  depends_on           = [aws_db_subnet_group.main]
}

resource "aws_route53_record" "rds_alias" {
  for_each = {
    for repo in var.repositories : repo.name => repo
    if repo.is_service && repo.override_with_shared_rds == null
  }
  zone_id = aws_route53_zone.public.zone_id
  name    = "rds.${each.key}.${var.environment}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [module.rds[each.key].rds_endpoint]
}

module "cluster" {
  count                    = var.use_eks ? 1 : 0
  source                   = "../modules/cluster"
  project_name             = var.project_name
  environment              = var.environment
  region                   = var.region
  vpc_id                   = module.vpc.vpc.vpc_id
  subnet_ids               = module.vpc.vpc.private_subnets
  principal_arn            = module.iam.account_arn
  route53_private_zone_arn = aws_route53_zone.private.arn
  route53_public_zone_arn  = aws_route53_zone.public.arn
}

locals {
  flat_credentials = {
    for item in flatten([
      for cred in var.credentials : [
        for obj in cred.objects : {
          key                     = "${obj.environment}-${cred.name}"
          name                    = "${obj.environment}/${var.project_name}/${cred.name}"
          description             = obj.description
          recovery_window_in_days = obj.environment == "prod" ? 7 : 0
          tags                    = { Sensitivity = "high" }
          value                   = obj.value
          namespace               = obj.namespace != null ? obj.namespace : "default"
        } if obj.environment == var.environment
      ]
    ]) : item.key => item
  }
}

resource "aws_secretsmanager_secret" "credentials" {
  for_each                = local.flat_credentials
  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = each.value.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "credentials_version" {
  for_each = local.flat_credentials

  secret_id     = aws_secretsmanager_secret.credentials[each.key].id
  secret_string = jsonencode(each.value.value)
}

resource "aws_acmpca_certificate_authority" "ca" {
  count = var.environment == "prod" ? 1 : 0
  type  = "ROOT"
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"
    subject {
      common_name  = var.domain_name
      organization = var.project_name
    }
  }
  permanent_deletion_time_in_days = 7
}

resource "aws_acmpca_certificate" "root" {
  count                       = var.environment == "prod" ? 1 : 0
  certificate_authority_arn   = aws_acmpca_certificate_authority.ca[count.index].arn
  certificate_signing_request = aws_acmpca_certificate_authority.ca[count.index].certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10
  }
}

resource "aws_acmpca_certificate_authority_certificate" "activation" {
  count                     = var.environment == "prod" ? 1 : 0
  certificate_authority_arn = aws_acmpca_certificate_authority.ca[count.index].arn
  certificate               = aws_acmpca_certificate.root[count.index].certificate
}

resource "aws_acm_certificate" "cert" {
  count                     = var.environment == "prod" ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  certificate_authority_arn = aws_acmpca_certificate_authority.ca[count.index].arn

  lifecycle {
    create_before_destroy = true
  }
}

module "rds_scaler" {
  source         = "../modules/lambda/rds_scheduler"
  project_name   = var.project_name
  environment    = var.environment
  start_schedule = "cron(0 12 ? * MON-FRI *)"
  stop_schedule  = "cron(0 18 ? * MON-FRI *)"
}

output "iam_access_key_id" {
  value     = module.iam.account_access_key_id
  sensitive = true
}

output "iam_secret_access_key" {
  value     = module.iam.account_secret_access_key
  sensitive = true
}

output "rds_secret_name_map" {
  value = {
    for repo in var.repositories :
    repo.name => {
      databaseName = repo.override_with_shared_rds != null ? repo.override_with_shared_rds : repo.name
      databaseSecretName = (repo.override_with_shared_rds != null
        ? module.rds[repo.override_with_shared_rds].rds_secret_name
        : module.rds[repo.name].rds_secret_name
      )
    }
    if repo.is_service || repo.override_with_shared_rds != null
  }
}

output "credentials_name_map" {
  value = {
    for cred in var.credentials :
    cred.name => {
      secretName = aws_secretsmanager_secret.credentials["${var.environment}-${cred.name}"].name
      namespace  = local.flat_credentials["${var.environment}-${cred.name}"].namespace
    }
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.cert[*].arn
}

output "private_hosted_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "public_hosted_zone_id" {
  value = aws_route53_zone.public.zone_id
}

output "cdn_url" {
  value = "https://cdn.${var.domain_name}"
}

output "pod_role_arn" {
  value = module.cluster[*].pod_role_arn
}

output "subnet_ids" {
  value = module.vpc.vpc.private_subnets
}
