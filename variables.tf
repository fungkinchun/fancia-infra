variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "domain_name" {
  type        = string
  description = "The domain name for the project"
}

variable "email" {
  type        = string
  description = "The email address for the project owner"
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

variable "repositories" {
  description = "List of repositories to create in CodeArtifact"
  type = list(object({
    name       = string
    is_service = bool
    override_with_shared_rds = optional(string)
  }))
}

variable "credentials" {
  description = "List of credential objects"
  type = list(object({
    name = string
    objects = list(object({
      environment = string
      description = string
      value       = map(string)
      namespace   = optional(string)
    }))
  }))
}
