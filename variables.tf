variable "project_name" {
  description = "Project name"
  type        = string
  default     = "terraform-aws-dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
  default     = "10.10.2.0/24"
}

variable "availability_zone" {
  description = "AWS Availability Zone"
  type        = string
  default     = "ap-south-1a"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (additional AWS charges)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Public IP allowed for SSH access"
  type        = string
  default     = "38.254.185.147/32"
}

variable "app_bucket_name" {
  description = "Application S3 bucket name"
  type        = string
  default     = "terraform-aws-dev-app-155335454656-ap-south-1"
}
