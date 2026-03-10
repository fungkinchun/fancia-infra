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

variable "repo_names" {
  description = "List of CodeArtifact repository names"
  type        = list(string)
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

variable "s3_credentials" {
  type        = map(string)
  sensitive   = true
  description = "Map of S3 credentials (access key and secret key) for the backend user"
}

variable "smtp_credentials" {
  type        = map(string)
  sensitive   = true
  description = "Map of SMTP credentials (username and password) for email sending"
}