output "bucket_id" {
  description = "Application S3 bucket name"
  value       = aws_s3_bucket.app.id
}

output "bucket_arn" {
  description = "Application S3 bucket ARN"
  value       = aws_s3_bucket.app.arn
}
