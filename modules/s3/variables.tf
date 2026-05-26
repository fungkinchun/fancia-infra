variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket"
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "region" {
  type        = string
  description = "The AWS region where the S3 bucket will be created"
}

variable "cloudfront_enabled" {
  type        = bool
  description = "Whether to enable CloudFront distribution for the S3 bucket"
  default     = false
}
