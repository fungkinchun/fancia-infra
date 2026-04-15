variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "myapp"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use (2 or 3 recommended)"
  type        = number
  default     = 3
}

variable "one_nat_gateway_per_az" {
  description = "Set to true for HA NAT (more expensive) or false for single NAT"
  type        = bool
  default     = true
}
