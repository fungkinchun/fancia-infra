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

module "dev_iam" {
  source       = "../../modules/iam"
  region       = var.region
  account_name = "${var.project_name}-${var.environment}-user"
}

module "dev_s3" {
  source       = "../../modules/s3"
  bucket_name  = var.project_name
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
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_codeartifact_domain" "codeartifact_domain" {
  domain = "${var.project_name}-${var.environment}"
}

module "dev_developertools" {
  source = "../../modules/developertools"
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
  depends_on              = [aws_codeartifact_domain.codeartifact_domain]
}

module "dev_vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 2
  environment  = var.environment
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = module.dev_vpc.vpc.public_subnets
}

resource "aws_route53_zone" "internal" {
  name = var.domain_name
  vpc {
    vpc_id = module.dev_vpc.vpc.vpc_id
  }
}

resource "aws_route53_zone" "external" {
  name          = var.domain_name
  comment       = "Public hosted zone for ${var.domain_name} – managed by Terraform"
  force_destroy = false
}

module "dev_rds" {
  source = "../../modules/rds"
  for_each = {
    for repo in var.repositories : repo.name => repo
    if repo.is_service && repo.override_with_shared_rds == null
  }
  project_name         = var.project_name
  repo_name            = each.key
  environment          = var.environment
  zone_id              = aws_route53_zone.internal.zone_id
  rds_id               = "${var.environment}-${each.key}"
  db_name              = var.project_name
  username             = var.username
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  vpc_id               = module.dev_vpc.vpc.vpc_id
  private_subnet_ids   = module.dev_vpc.vpc.database_subnets
  allowed_cidr_blocks  = [module.dev_vpc.vpc.vpc_cidr_block]
  db_subnet_group_name = aws_db_subnet_group.main.name
  depends_on           = [aws_db_subnet_group.main]
}

resource "aws_route53_record" "rds_alias" {
  for_each = {
    for repo in var.repositories : repo.name => repo
    if repo.is_service && repo.override_with_shared_rds == null
  }
  zone_id = aws_route53_zone.external.zone_id
  name    = "rds.${each.key}.${var.environment}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [module.dev_rds[each.key].rds_endpoint]
}

module "dev_eks" {
  source           = "../../modules/eks"
  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.dev_vpc.vpc.vpc_id
  subnet_ids       = module.dev_vpc.vpc.private_subnets
  region           = var.region
  principal_arn    = module.dev_iam.account_arn
  route53_zone_arn = aws_route53_zone.external.arn
}

locals {
  flat_credentials = {
    for item in flatten([
      for cred in var.credentials : [
        for obj in cred.objects : {
          key                     = "${obj.environment}-${cred.name}"
          name                    = "${obj.environment}/${var.project_name}-backend-user/${cred.name}"
          description             = obj.description
          recovery_window_in_days = obj.environment == "prod" ? 7 : 0
          tags                    = { Sensitivity = "high" }
          value                   = obj.value
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
  type = "ROOT"
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
  certificate_authority_arn   = aws_acmpca_certificate_authority.ca.arn
  certificate_signing_request = aws_acmpca_certificate_authority.ca.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10
  }
}

resource "aws_acmpca_certificate_authority_certificate" "activation" {
  certificate_authority_arn = aws_acmpca_certificate_authority.ca.arn
  certificate               = aws_acmpca_certificate.root.certificate
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  certificate_authority_arn = aws_acmpca_certificate_authority.ca.arn

  lifecycle {
    create_before_destroy = true
  }
}

output "iam_access_key_id" {
  value     = module.dev_iam.account_access_key_id
  sensitive = true
}

output "iam_secret_access_key" {
  value     = module.dev_iam.account_secret_access_key
  sensitive = true
}

output "rds_secret_name_map" {
  value = {
    for repo in var.repositories :
    repo.name => {
      databaseName = repo.override_with_shared_rds != null ? repo.override_with_shared_rds : null
      databaseSecretName = (repo.override_with_shared_rds != null
        ? module.dev_rds[repo.override_with_shared_rds].rds_secret_name
        : null
      )
    }
    if repo.is_service || repo.override_with_shared_rds != null
  }
}


output "vpc_id" {
  value = module.dev_vpc.vpc_id
}

output "private_ca_arn" {
  value = aws_acmpca_certificate_authority.ca.arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.cert.arn
}

output "hosted_zone_id" {
  value = aws_route53_zone.external.zone_id
}

output "pod_role_arn" {
  value = module.dev_eks.pod_role_arn
}
