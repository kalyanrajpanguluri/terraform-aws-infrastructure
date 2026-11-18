output "state_bucket_name" {
  description = "S3 bucket name to configure in Terraform S3 backends."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_account_id" {
  description = "AWS account in which the backend bucket was created."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region containing the backend bucket."
  value       = var.aws_region
}
