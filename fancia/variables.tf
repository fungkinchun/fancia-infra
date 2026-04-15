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

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "repositories" {
  description = "List of CodeArtifact repositories"
  type = list(object({
    name                     = string
    is_service               = bool
    override_with_shared_rds = optional(string)
  }))
}

variable "github_username" {
  type        = string
  description = "The GitHub username for authentication"
}

variable "github_token" {
  type        = string
  description = "The GitHub token for authentication"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of AZs to use (2 or 3 recommended)"
  type        = number
  default     = 3
}

variable "instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB"
  type        = number
  default     = 20
}

variable "username" {
  description = "Master username"
  type        = string
  default     = "admin"
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
