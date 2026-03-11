variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "repo_name" {
  type        = string
  description = "Name of the CodeArtifact repository"
}

variable "codebuild_role_arn" {
  type        = string
  description = "ARN of the CodeBuild role"
}

variable "codestar_connection_arn" {
  type        = string
  description = "ARN of the CodeStar connection for GitHub"
}

variable "github_username" {
  type        = string
  description = "GitHub username for authentication"
}

variable "github_token" {
  type        = string
  description = "GitHub token for authentication"
}
