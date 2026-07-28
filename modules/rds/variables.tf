variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "repo_name" {
  type        = string
  description = "The name of the repository (e.g., backend, frontend)"
}

variable "rds_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
  default     = "admin"
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

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (at least 2 for subnet group)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS (e.g., VPC CIDR or bastion)"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "db_subnet_group_name" {
  description = "Name for the DB subnet group"
  type        = string
  default     = "rds-subnet-group"
}

variable "zone_id" {
  description = "Route53 Hosted Zone ID for creating alias record"
  type        = string
}
