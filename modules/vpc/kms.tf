data "aws_iam_policy_document" "vpc_flow_logs_kms" {
  statement {
    sid    = "EnableAccountKeyAdministration"
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

  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    actions = [
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Describe*",
      "kms:Decrypt"
    ]

    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [local.vpc_flow_logs_log_group_arn]
    }
  }
}

resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS encryption key for Terraform VPC Flow Logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.vpc_flow_logs_kms.json

  tags = {
    Name      = "${var.project_name}-vpc-flow-logs-kms"
    ManagedBy = "Terraform"
    Purpose   = "CloudWatch VPC Flow Logs encryption"
  }
}

resource "aws_kms_alias" "vpc_flow_logs" {
  name          = "alias/${var.project_name}-vpc-flow-logs"
  target_key_id = aws_kms_key.vpc_flow_logs.key_id
}
