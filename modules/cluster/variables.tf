variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the EKS cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the EKS cluster"
}

variable "principal_arn" {
  type        = string
  description = "ARN of the IAM principal for EKS cluster administration"
}

variable "route53_private_zone_arn" {
  type        = string
  description = "Route53 private hosted zone ARN"
}

variable "route53_public_zone_arn" {
  type        = string
  description = "Route53 public hosted zone ARN"
}
