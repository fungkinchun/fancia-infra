variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "domain_name" {
  type        = string
  description = "The domain name for the project"
}

variable "region" {
  type        = string
  description = "The region of the project"
  default     = "eu-west-2"
}

variable "github_username" {
  type        = string
  description = "The GitHub username for authentication"
}

variable "github_token" {
  type        = string
  description = "The GitHub token for authentication"
}

variable "repo_names" {
  type        = list(string)
  description = "List of repository names to create in CodeArtifact"
  default     = []
}

variable "s3_credentials" {
  type        = map(string)
  description = "S3 credentials for backend user"
}

variable "smtp_credentials" {
  type        = map(string)
  description = "SMTP credentials for backend user"
}
