variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Approved public IP allowed to connect through SSH"
  type        = string
}
