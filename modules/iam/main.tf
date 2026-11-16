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
      "s3:GetBucket*",
      "s3:GetAccelerateConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:ListBucket"
    ]

    resources = [
      local.app_bucket_arn
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
      "iam:ListAttachedRolePolicies"
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
