data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "scheduler.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "rds_scheduler_lambda" {
  name               = "lambda-rds-start-stop-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy" "rds_permissions" {
  role = aws_iam_role.rds_scheduler_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:StopDBInstance",
          "rds:StartDBInstance",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/rds_scheduler.zip"
}

resource "aws_lambda_function" "rds_scheduler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "rds-start-stop-scheduler"
  role             = aws_iam_role.rds_scheduler_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_scheduler_schedule" "start_rds" {
  name                         = "start-rds"
  schedule_expression          = var.start_schedule
  schedule_expression_timezone = var.timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.rds_scheduler.arn
    role_arn = aws_iam_role.rds_scheduler_lambda.arn

    input = jsonencode({
      action = "start",
      tags = {
        Project     = var.project_name,
        Environment = var.environment
      }
    })
  }
}

resource "aws_scheduler_schedule" "stop_rds" {
  name                         = "stop-rds"
  schedule_expression          = var.stop_schedule
  schedule_expression_timezone = var.timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.rds_scheduler.arn
    role_arn = aws_iam_role.rds_scheduler_lambda.arn

    input = jsonencode({
      action = "stop",
      tags = {
        Project     = var.project_name,
        Environment = var.environment
      }
    })
  }
}

resource "aws_lambda_permission" "allow_start_scheduler" {
  statement_id  = "AllowExecutionFromStartScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_scheduler.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.start_rds.arn
}

resource "aws_lambda_permission" "allow_stop_scheduler" {
  statement_id  = "AllowExecutionFromStopScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_scheduler.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.stop_rds.arn
}
