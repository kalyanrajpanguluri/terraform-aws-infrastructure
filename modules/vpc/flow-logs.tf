data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  vpc_flow_logs_log_group_name = "/aws/vpc/${var.project_name}/flow-logs"

  vpc_flow_logs_log_group_arn = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.vpc_flow_logs_log_group_name}"
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"
      ]
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_permissions" {
  statement {
    sid    = "WriteFlowLogs"
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:CreateLogStream"
    ]

    resources = ["${local.vpc_flow_logs_log_group_arn}:*"]
  }

  statement {
    sid       = "DescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = local.vpc_flow_logs_log_group_name
  retention_in_days = 30
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn

  tags = {
    Name      = "${var.project_name}-vpc-flow-logs"
    ManagedBy = "Terraform"
    Purpose   = "VPC network traffic monitoring"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "${var.project_name}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json

  tags = {
    Name      = "${var.project_name}-vpc-flow-logs-role"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "${var.project_name}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_permissions.json
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

  max_aggregation_interval = 600

  tags = {
    Name      = "${var.project_name}-vpc-flow-log"
    ManagedBy = "Terraform"
  }
}
