data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Customer-managed KMS key for application bucket encryption.
data "aws_iam_policy_document" "app_bucket_kms" {
  statement {
    sid    = "EnableAccountIAMPermissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "app_bucket" {
  description             = "Customer-managed KMS key for ${var.project_name} application S3 bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.app_bucket_kms.json

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "${var.project_name}-app-s3-kms"
    ManagedBy = "Terraform"
    Purpose   = "Application S3 bucket encryption"
  }
}

resource "aws_kms_alias" "app_bucket" {
  name          = "alias/${var.project_name}-app-s3"
  target_key_id = aws_kms_key.app_bucket.key_id
}

# Dedicated S3 server access logging destination.
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.bucket_name}-access-logs"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "${var.bucket_name}-access-logs"
    ManagedBy = "Terraform"
    Purpose   = "S3 server access audit logs"
  }
}

# Keep ACLs disabled on the destination bucket.
resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS requires SSE-S3 for S3 server access log delivery.
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Permit only the S3 logging service to deliver logs from this source bucket.
data "aws_iam_policy_document" "access_logs" {
  statement {
    sid    = "AllowS3ServerAccessLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.access_logs.arn}/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.app.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json

  depends_on = [
    aws_s3_bucket_public_access_block.access_logs
  ]
}

# Enable access logging on the application bucket.
resource "aws_s3_bucket_logging" "app" {
  bucket        = aws_s3_bucket.app.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/${var.bucket_name}/"

  depends_on = [
    aws_s3_bucket_policy.access_logs
  ]
}

# Expire noncurrent application object versions after 30 days.
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  depends_on = [
    aws_s3_bucket_versioning.app
  ]

  rule {
    id     = "expire-noncurrent-versions-after-30-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Deny all non-TLS access to the application bucket.
data "aws_iam_policy_document" "app_bucket_transport" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.app.arn,
      "${aws_s3_bucket.app.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app_bucket_transport.json
}
