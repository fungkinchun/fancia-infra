variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "region" {
  type        = string
  description = "AWS region for the EKS cluster"
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the EKS cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the EKS cluster"
}

variable "principal_arn" {
  type        = string
  description = "ARN of the Kubernetes service account that will assume the IAM role"
}

variable "route53_zone_arn" {
  type        = string
  description = "Route53 hosted zone ARN for the EKS cluster"
}