data "aws_caller_identity" "current" {}

locals {
  name = "tfaws-pipeline-temp"

  buckets = {
    raw = {
      name            = "${local.name}-raw-${data.aws_caller_identity.current.account_id}-ap-south-1"
      expiration_days = 14
    }
    curated = {
      name            = "${local.name}-curated-${data.aws_caller_identity.current.account_id}-ap-south-1"
      expiration_days = 30
    }
    results = {
      name            = "${local.name}-results-${data.aws_caller_identity.current.account_id}-ap-south-1"
      expiration_days = 3
    }
  }

  validator_name = "${local.name}-validator"
  glue_job_name  = "${local.name}-etl"
  database_name  = "tfaws_pipeline_temp_db"
}

# ---------------------------------------------------------
# S3 DATA LAKE BUCKETS
# ---------------------------------------------------------

resource "aws_s3_bucket" "pipeline" {
  for_each = local.buckets

  bucket        = each.value.name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "pipeline" {
  for_each = aws_s3_bucket.pipeline

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "pipeline" {
  for_each = aws_s3_bucket.pipeline

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline" {
  for_each = aws_s3_bucket.pipeline

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pipeline" {
  for_each = aws_s3_bucket.pipeline

  bucket = each.value.id

  rule {
    id     = "temporary-data-expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = local.buckets[each.key].expiration_days
    }
  }
}

resource "aws_s3_bucket_policy" "pipeline" {
  for_each = aws_s3_bucket.pipeline

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        each.value.arn,
        "${each.value.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.pipeline]
}

# ---------------------------------------------------------
# LAMBDA VALIDATOR
# ---------------------------------------------------------

resource "aws_cloudwatch_log_group" "validator" {
  name              = "/aws/lambda/${local.validator_name}"
  retention_in_days = 7
}

resource "aws_iam_role" "lambda" {
  name = "${local.name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "${local.name}-lambda-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.validator.arn}:*"
    }]
  })
}

resource "aws_lambda_function" "validator" {
  function_name    = local.validator_name
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "validator.lambda_handler"
  filename         = "${path.module}/lambda/validator.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/validator.zip")
  timeout          = 30
  memory_size      = 128

  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.validator
  ]
}

# ---------------------------------------------------------
# GLUE DATA CATALOG AND ETL
# ---------------------------------------------------------

resource "aws_glue_catalog_database" "pipeline" {
  name         = local.database_name
  location_uri = "s3://${aws_s3_bucket.pipeline["curated"].bucket}/"
}

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.pipeline["raw"].bucket
  key    = "scripts/etl.py"
  source = "${path.module}/glue/etl.py"
  etag   = filemd5("${path.module}/glue/etl.py")
}

resource "aws_iam_role" "glue" {
  name = "${local.name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue" {
  name = "${local.name}-glue-access"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pipeline["raw"].arn,
          aws_s3_bucket.pipeline["curated"].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.pipeline["raw"].arn}/raw/*",
          "${aws_s3_bucket.pipeline["raw"].arn}/scripts/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = "${aws_s3_bucket.pipeline["curated"].arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.pipeline["curated"].arn}/processed/*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartitions",
          "glue:BatchGetPartition",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:BatchCreatePartition"
        ]
        Resource = [
          "arn:aws:glue:ap-south-1:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:ap-south-1:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.pipeline.name}",
          "arn:aws:glue:ap-south-1:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.pipeline.name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:ap-south-1:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/crawlers:*",
          "arn:aws:logs:ap-south-1:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/error:*",
          "arn:aws:logs:ap-south-1:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/logs-v2:*",
          "arn:aws:logs:ap-south-1:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/output:*"
        ]
      }
    ]
  })
}

resource "aws_glue_job" "pipeline" {
  name     = local.glue_job_name
  role_arn = aws_iam_role.glue.arn

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.pipeline["raw"].bucket}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }

  depends_on = [aws_iam_role_policy.glue]
}

resource "aws_glue_crawler" "pipeline" {
  name          = "${local.name}-crawler"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.pipeline.name

  s3_target {
    path = "s3://${aws_s3_bucket.pipeline["curated"].bucket}/processed/"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  depends_on = [aws_iam_role_policy.glue]
}

# ---------------------------------------------------------
# STEP FUNCTIONS ORCHESTRATION
# ---------------------------------------------------------

resource "aws_iam_role" "step_functions" {
  name = "${local.name}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${local.name}-sfn-access"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.validator.arn
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = aws_glue_job.pipeline.arn
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = aws_glue_crawler.pipeline.arn
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.glue.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "glue.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_sfn_state_machine" "pipeline" {
  name     = "${local.name}-orchestrator"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment        = "Temporary S3 to Glue data pipeline"
    StartAt        = "ValidateIncomingFile"
    TimeoutSeconds = 1800

    States = {
      ValidateIncomingFile = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"

        Parameters = {
          FunctionName = aws_lambda_function.validator.arn
          "Payload.$"  = "$"
        }

        ResultSelector = {
          "bucket.$" = "$.Payload.bucket"
          "key.$"    = "$.Payload.key"
        }

        ResultPath = "$.validated"
        Next       = "RunGlueETL"
      }

      RunGlueETL = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"

        Parameters = {
          JobName = aws_glue_job.pipeline.name

          Arguments = {
            "--source_bucket.$" = "$.validated.bucket"
            "--source_key.$"    = "$.validated.key"
            "--target_bucket"   = aws_s3_bucket.pipeline["curated"].bucket
          }
        }

        Next = "StartGlueCrawler"
      }

      StartGlueCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = aws_glue_crawler.pipeline.name
        }
        Next = "WaitForCrawler"
      }

      WaitForCrawler = {
        Type    = "Wait"
        Seconds = 15
        Next    = "GetCrawlerStatus"
      }

      GetCrawlerStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:getCrawler"
        Parameters = {
          Name = aws_glue_crawler.pipeline.name
        }
        ResultPath = "$.crawler"
        Next       = "CheckCrawlerState"
      }

      CheckCrawlerState = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.crawler.Crawler.State"
            StringEquals = "RUNNING"
            Next         = "WaitForCrawler"
          },
          {
            Variable     = "$.crawler.Crawler.State"
            StringEquals = "READY"
            Next         = "CheckCrawlerResult"
          }
        ]
        Default = "WaitForCrawler"
      }

      CheckCrawlerResult = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.crawler.Crawler.LastCrawl.Status"
            StringEquals = "SUCCEEDED"
            Next         = "PipelineSucceeded"
          },
          {
            Variable     = "$.crawler.Crawler.LastCrawl.Status"
            StringEquals = "FAILED"
            Next         = "CrawlerFailed"
          }
        ]
        Default = "WaitForCrawler"
      }

      PipelineSucceeded = {
        Type = "Succeed"
      }

      CrawlerFailed = {
        Type  = "Fail"
        Error = "GlueCrawlerFailed"
        Cause = "The Glue crawler did not complete successfully."
      }
    }
  })

  depends_on = [aws_iam_role_policy.step_functions]
}

# ---------------------------------------------------------
# EVENTBRIDGE S3 EVENT TRIGGER
# ---------------------------------------------------------

resource "aws_s3_bucket_notification" "raw" {
  bucket      = aws_s3_bucket.pipeline["raw"].id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "raw_object_created" {
  name = "${local.name}-raw-object-created"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]

    detail = {
      bucket = {
        name = [aws_s3_bucket.pipeline["raw"].bucket]
      }
      object = {
        key = [{
          prefix = "raw/"
        }]
      }
    }
  })

  depends_on = [aws_s3_bucket_notification.raw]
}

resource "aws_iam_role" "eventbridge" {
  name = "${local.name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.raw_object_created.arn
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "${local.name}-eventbridge-start-sfn"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.pipeline.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "pipeline" {
  rule     = aws_cloudwatch_event_rule.raw_object_created.name
  arn      = aws_sfn_state_machine.pipeline.arn
  role_arn = aws_iam_role.eventbridge.arn

  depends_on = [aws_iam_role_policy.eventbridge]
}

# ---------------------------------------------------------
# ATHENA WORKGROUP
# ---------------------------------------------------------

resource "aws_athena_workgroup" "pipeline" {
  name = "${local.name}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 1000000000

    result_configuration {
      output_location = "s3://${aws_s3_bucket.pipeline["results"].bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }
}

# ---------------------------------------------------------
# CLOUDWATCH MONITORING
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name}-lambda-errors"
  alarm_description   = "Lambda validator reported one or more errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.validator.function_name
  }
}

# ---------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------

output "raw_bucket" {
  value = aws_s3_bucket.pipeline["raw"].bucket
}

output "curated_bucket" {
  value = aws_s3_bucket.pipeline["curated"].bucket
}

output "athena_results_bucket" {
  value = aws_s3_bucket.pipeline["results"].bucket
}

output "glue_database" {
  value = aws_glue_catalog_database.pipeline.name
}

output "glue_job" {
  value = aws_glue_job.pipeline.name
}

output "step_functions_arn" {
  value = aws_sfn_state_machine.pipeline.arn
}

output "athena_workgroup" {
  value = aws_athena_workgroup.pipeline.name
}

output "glue_crawler" {
  value = aws_glue_crawler.pipeline.name
}
