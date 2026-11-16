variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the IAM role"
  type        = string
  default     = "main"
}

variable "state_bucket_name" {
  description = "Terraform remote state S3 bucket"
  type        = string
}

variable "state_key" {
  description = "Terraform remote state key"
  type        = string
}

variable "app_bucket_name" {
  description = "Application S3 bucket"
  type        = string
}

variable "role_name" {
  description = "GitHub Actions IAM role name"
  type        = string
  default     = "terraform-github-actions-plan"
}
