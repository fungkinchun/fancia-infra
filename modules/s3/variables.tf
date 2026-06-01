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

variable "domain_name" {
  type        = string
  description = "Apex domain (e.g. fancia.co.uk). CDN hostname is cdn.<domain_name>."
  default     = ""
}

variable "public_zone_id" {
  type        = string
  description = "Route 53 public hosted zone ID for CDN alias and ACM validation"
  default     = ""
}
