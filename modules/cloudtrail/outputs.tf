output "trail_arn" {
  description = "CloudTrail audit trail ARN"
  value       = aws_cloudtrail.audit.arn
}

output "log_bucket_name" {
  description = "Dedicated CloudTrail log bucket"
  value       = aws_s3_bucket.cloudtrail.id
}
