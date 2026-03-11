data "aws_caller_identity" "current" {}

locals {
  full_repo_name   = "${var.project_name}-backend-${var.repo_name}"
  full_domain_name = "${var.project_name}-${var.environment}"
}

resource "aws_codebuild_project" "codebuild_project" {
  name         = local.full_repo_name
  service_role = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "ENV"
      value = var.environment
    }

    environment_variable {
      name  = "DOMAIN_NAME"
      value = local.full_domain_name
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "REPO_NAME"
      value = var.repo_name
    }

    environment_variable {
      name  = "ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_codeartifact_repository" "codeartifact_repo" {
  repository = local.full_repo_name
  domain     = local.full_domain_name
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.full_repo_name}-artifacts-bucket"
  force_destroy = true
}

resource "aws_codepipeline" "codepipeline" {
  name          = local.full_repo_name
  role_arn      = var.codebuild_role_arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "${var.github_username}/${local.full_repo_name}"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = []
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.name
      }
    }
  }
}

resource "aws_ecr_repository" "ecr_repository" {
  name = local.full_repo_name

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = var.environment != "prod" ? true : false
}

resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy" {
  repository = aws_ecr_repository.ecr_repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release-", "prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Keep max 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
