variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod)"
}

variable "timezone" {
  description = "Timezone for schedules (e.g. Europe/London)"
  type        = string
  default     = "Europe/London"
}

variable "start_schedule" {
  description = "Cron expression to START the RDS (08:00 UTC MON-FRI)"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "stop_schedule" {
  description = "Cron expression to STOP the RDS (18:00 UTC MON-FRI)"
  type        = string
  default     = "cron(0 18 ? * MON-FRI *)"
}