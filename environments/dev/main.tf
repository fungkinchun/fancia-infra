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
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "dev_cicd" {
  source                  = "../../modules/cicd"
  for_each                = toset(var.repo_names)
  project_name            = var.project_name
  environment             = var.environment
  repo_name               = each.key
  codestar_connection_arn = aws_codestarconnections_connection.github.arn
  codebuild_role_arn      = aws_iam_role.codebuild_role.arn
  github_username         = var.github_username
  github_token            = var.github_token
  depends_on              = [aws_codeartifact_domain.codeartifact_domain]
}

module "dev_network" {
  source       = "../../modules/network"
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 2
  environment  = var.environment
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = module.dev_network.vpc.public_subnets

  tags = {
    Name = "${var.project_name}-subnet-group"
  }
}

resource "aws_route53_zone" "internal" {
  name = "${var.project_name}.${var.environment}"
  vpc {
    vpc_id = module.dev_network.vpc.vpc_id
  }
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Terraform   = "true"
  }
}

module "dev_rds" {
  source               = "../../modules/rds"
  for_each             = toset(var.repo_names)
  project_name         = var.project_name
  repo_name            = each.key
  environment          = var.environment
  zone_id              = aws_route53_zone.internal.zone_id
  rds_id               = "${var.environment}-${each.key}"
  db_name              = var.project_name
  username             = var.username
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  vpc_id               = module.dev_network.vpc.vpc_id
  private_subnet_ids   = module.dev_network.vpc.database_subnets
  allowed_cidr_blocks  = [module.dev_network.vpc.vpc_cidr_block]
  db_subnet_group_name = aws_db_subnet_group.main.name
  depends_on           = [aws_db_subnet_group.main]
}

module "dev_eks" {
  source        = "../../modules/eks"
  project_name  = var.project_name
  environment   = var.environment
  vpc_id        = module.dev_network.vpc.vpc_id
  subnet_ids    = module.dev_network.vpc.private_subnets
  namespace     = var.project_name
  region        = var.region
  principal_arn = module.dev_iam.account_arn
}

resource "aws_secretsmanager_secret" "s3_credentials" {
  name                    = "${var.environment}/${var.project_name}-backend-user/s3"
  description             = "S3 credentials for ${var.project_name}-backend-user in ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 7 : 0

  tags = {
    Environment = var.environment
    Project     = "${var.project_name}-backend-user"
    Terraform   = "true"
    Sensitivity = "high"
  }
}

resource "aws_secretsmanager_secret_version" "s3_credentials_version" {
  secret_id     = aws_secretsmanager_secret.s3_credentials.id
  secret_string = jsonencode(var.s3_credentials)
}

resource "aws_secretsmanager_secret" "smtp_credentials" {
  name                    = "${var.environment}/${var.project_name}-backend-user/smtp"
  description             = "SMTP credentials for ${var.project_name}-backend-user in ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 7 : 0

  tags = {
    Environment = var.environment
    Project     = "${var.project_name}-backend-user"
    Terraform   = "true"
    Sensitivity = "high"
  }
}

resource "aws_secretsmanager_secret_version" "smtp_credentials_version" {
  secret_id     = aws_secretsmanager_secret.smtp_credentials.id
  secret_string = jsonencode(var.smtp_credentials)
}


resource "aws_acmpca_certificate_authority" "ca" {
  type = "ROOT"
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"
    subject {
      common_name = "fancia.com"
      organization = "Fancia"
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


output "dev_iam_access_key_id" {
  value     = module.dev_iam.account_access_key_id
  sensitive = true
}

output "dev_iam_secret_access_key" {
  value     = module.dev_iam.account_secret_access_key
  sensitive = true
}

output "rds_secret_name_map" {
  value = { for k, v in module.dev_rds : k => v.rds_secret_name }
}

output "vpc_id" {
  value = module.dev_network.vpc_id
}

output "private_ca_arn" {
  value = aws_acmpca_certificate_authority.ca.arn
}