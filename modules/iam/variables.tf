variable "account_name" {
  description = "The name of the account"
}

variable "region" {
  description = "The AWS region to use"
}

variable "account_policy_arn" {
  description = "The ARN of the policy to attach to the account"
  default     = "arn:aws:iam::aws:policy/AdministratorAccess"
}
