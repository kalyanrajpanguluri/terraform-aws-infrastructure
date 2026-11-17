output "vpc_id" {
  description = "Created VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = module.vpc.private_subnet_id
}

output "ssh_security_group_id" {
  description = "SSH security group ID"
  value       = module.security_groups.ssh_security_group_id
}

output "app_bucket_name" {
  description = "Application S3 bucket name"
  value       = module.s3.bucket_id
}

output "app_bucket_arn" {
  description = "Application S3 bucket ARN"
  value       = module.s3.bucket_arn
}

output "github_actions_role_arn" {
  description = "GitHub Actions plan-only IAM role"
  value       = module.github_oidc.github_actions_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider"
  value       = module.github_oidc.github_oidc_provider_arn
}

output "github_oidc_subject" {
  description = "Exact GitHub subject trusted by the IAM role"
  value       = module.github_oidc.github_oidc_subject
}

output "cloudtrail_trail_arn" {
  description = "CloudTrail audit trail ARN"
  value       = module.cloudtrail.trail_arn
}

output "cloudtrail_log_bucket" {
  description = "CloudTrail audit log bucket"
  value       = module.cloudtrail.log_bucket_name
}
