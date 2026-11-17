variable "project_name" {
  description = "Project name used for CloudTrail resources"
  type        = string
}

variable "app_bucket_arn" {
  description = "Application S3 bucket ARN to monitor"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudTrail logs"
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "CloudTrail log retention must be at least 90 days."
  }
}
