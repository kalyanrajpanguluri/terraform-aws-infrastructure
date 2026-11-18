data "aws_caller_identity" "current" {}

locals {
  github_subject = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}:ref:refs/heads/${var.github_branch}"

  oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_name}"

  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.role_name}-policy"

  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"
  state_object_arn = "${local.state_bucket_arn}/${var.state_key}"
  lock_object_arn  = "${local.state_object_arn}.tflock"

  app_bucket_arn = "arn:aws:s3:::${var.app_bucket_name}"
}

# GitHub Actions OIDC identity provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name    = "github-actions-oidc"
    Project = "Terraform-AWS-Infrastructure"
  }
}

# Trust policy: only the configured repository and branch can assume this role
data "aws_iam_policy_document" "github_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_subject]
    }
  }
}

# IAM role for GitHub Actions Terraform plan
resource "aws_iam_role" "github_actions" {
  name                 = var.role_name
  description          = "Plan-only access for the approved GitHub Actions repository"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600

  tags = {
    Name    = var.role_name
    Project = "Terraform-AWS-Infrastructure"
    Purpose = "GitHub Actions Terraform plan only"
  }
}

# Permissions required to run Terraform plan
data "aws_iam_policy_document" "github_plan" {

  # Read-only EC2 infrastructure information
  statement {
    sid    = "ReadEC2Infrastructure"
    effect = "Allow"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeFlowLogs",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs"
    ]

    resources = ["*"]
  }

  # Read application bucket configuration only
  # No permission to read or download application objects
  statement {
    sid    = "ReadApplicationBucket"
    effect = "Allow"

    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket"
    ]

    resources = [
      local.app_bucket_arn
    ]
  }

  # Read access-log bucket versioning
  statement {
    sid     = "ReadAccessLogBucketVersioning"
    effect  = "Allow"
    actions = ["s3:GetBucketVersioning"]
    resources = [
      "arn:aws:s3:::terraform-aws-dev-app-155335454656-ap-south-1-access-logs"
    ]
  }

  # Read the VPC Flow Logs IAM role
  statement {
    sid     = "ReadVpcFlowLogsRole"
    effect  = "Allow"
    actions = ["iam:GetRole", "iam:ListRolePolicies", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies"]
    resources = [
      "arn:aws:iam::155335454656:role/terraform-aws-dev-vpc-flow-logs-role"
    ]
  }

  # Read the VPC Flow Logs KMS key
  statement {
    sid     = "ReadVpcFlowLogsKmsKey"
    effect  = "Allow"
    actions = ["kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags"]
    resources = [
      "arn:aws:kms:ap-south-1:155335454656:key/24bd8987-6c26-412f-8a20-c0beac870cd8"
    ]
  }

  # Read Terraform state bucket location
  statement {
    sid    = "ReadStateBucketLocation"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation"
    ]

    resources = [
      local.state_bucket_arn
    ]
  }

  # List only the Terraform project state prefix
  statement {
    sid    = "ListTerraformStatePrefix"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      local.state_bucket_arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["terraform/project/*"]
    }
  }

  # Read the Terraform state file
  statement {
    sid    = "ReadTerraformState"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      local.state_object_arn
    ]
  }

  # Manage only the Terraform state lock file
  # Locking requires GetObject, PutObject and DeleteObject
  statement {
    sid    = "ManageTerraformLockFile"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      local.lock_object_arn
    ]
  }

  # Read GitHub OIDC provider configuration
  statement {
    sid    = "ReadIAMConfiguration"
    effect = "Allow"

    actions = [
      "iam:GetOpenIDConnectProvider"
    ]

    resources = [
      local.oidc_provider_arn
    ]
  }

  # Read GitHub IAM role configuration
  statement {
    sid    = "ReadGitHubRole"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies"
    ]

    resources = [
      local.role_arn
    ]
  }

  # Read GitHub IAM policy configuration
  statement {
    sid    = "ReadGitHubPolicy"
    effect = "Allow"

    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion"
    ]

    resources = [
      local.policy_arn
    ]
  }

  # Read configuration for the three Terraform-managed S3 buckets.
  statement {
    sid    = "ReadManagedS3BucketConfigurations"
    effect = "Allow"

    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketCORS",
      "s3:GetBucketWebsite",
      "s3:GetBucketRequestPayment",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::terraform-aws-dev-app-155335454656-ap-south-1",
      "arn:aws:s3:::terraform-aws-dev-app-155335454656-ap-south-1-access-logs",
      "arn:aws:s3:::terraform-aws-dev-155335454656-ap-south-1-cloudtrail-logs"
    ]
  }

  # Read the CloudTrail and application-bucket KMS keys.
  statement {
    sid    = "ReadCloudTrailAndApplicationKmsKeys"
    effect = "Allow"

    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags"
    ]

    resources = [
      "arn:aws:kms:ap-south-1:155335454656:key/6cc1c0b8-003f-4b77-af74-21990f984fe4",
      "arn:aws:kms:ap-south-1:155335454656:key/9c15efd3-1769-41a7-bf90-cadfcb580646"
    ]
  }

  # Read CloudWatch log group metadata.
  statement {
    sid       = "ReadCloudWatchLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups", "logs:ListTagsForResource"]
    resources = ["*"]
  }

  # KMS alias discovery is an account-level read operation.
  statement {
    sid       = "ListKmsAliases"
    effect    = "Allow"
    actions   = ["kms:ListAliases"]
    resources = ["*"]
  }

}

# Create the plan-only IAM policy
resource "aws_iam_policy" "github_plan" {
  name        = "${var.role_name}-policy"
  description = "Read-only AWS infrastructure and Terraform plan backend permissions"
  policy      = data.aws_iam_policy_document.github_plan.json
}

# Attach the policy to the GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_plan" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_plan.arn
}
