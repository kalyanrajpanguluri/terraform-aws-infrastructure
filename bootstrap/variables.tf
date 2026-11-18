variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
  default     = ""
}

variable "project_prefix" {
  description = "Prefix used when deriving a state bucket name."
  type        = string
  default     = "terraform-state"
}

variable "force_destroy" {
  description = "Allow deletion of a non-empty state bucket. Keep false."
  type        = bool
  default     = false
}
