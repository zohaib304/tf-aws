resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Bucket 1: Worker upload images here
resource "aws_s3_bucket" "images" {
  bucket        = "${var.project_name}-images-${random_id.suffix.hex}"
  force_destroy = true
  tags          = local.common_tags
}

# Block all public access 
resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket 2: Violation images archived here
resource "aws_s3_bucket" "violations" {
  bucket        = "${var.project_name}-violations-${random_id.suffix.hex}"
  force_destroy = true
  tags          = local.common_tags
}

# Dynamodb table 
resource "aws_dynamodb_table" "safety_log" {
  name         = "${var.project_name}-safety-log"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_key"
  range_key    = "timestamp"

  attribute {
    name = "image_key"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = local.common_tags
}

# SNS Topic for email alets
resource "aws_sns_topic" "safety_alerts" {
  name = "${var.project_name}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.safety_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM Role for lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs (for debugging)
      { Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:*" },
      # S3 (read uploads, write violations)
      { Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
      Resource = ["${aws_s3_bucket.images.arn}/*", "${aws_s3_bucket.violations.arn}/*"] },
      # Rekognition (AI detection)
      { Effect = "Allow"
        Action = ["rekognition:DetectLabels", "rekognition:DetectProtectiveEquipment"]
      Resource = "*" },
      # DynamoDB (write audit logs)
      { Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
      Resource = aws_dynamodb_table.safety_log.arn },
      # SNS (send alerts)
      { Effect = "Allow"
        Action = ["sns:Publish"]
      Resource = aws_sns_topic.safety_alerts.arn }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

resource "aws_lambda_function" "safety_checker" {
  function_name    = "${var.project_name}-checker"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.safety_log.name
      SNS_TOPIC_ARN     = aws_sns_topic.safety_alerts.arn
      VIOLATIONS_BUCKET = aws_s3_bucket.violations.bucket
      CONFIDENCE_MIN    = var.confidence_threshold
    }
  }
  tags = local.common_tags
}

# Allow s3 to invoke lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.safety_checker.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}

resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.safety_checker.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.safety_checker.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}
