provider "aws" {
  region = "us-east-1"
}

data "archive_file" "lambda_trigger" {
  type        = "zip"
  source_file = "${path.module}/lambda/trigger/handler.py"
  output_path = "${path.module}/lambda/trigger/handler.zip"
}

moved {
  from = aws_iam_role.mediaconvert_rol
  to   = aws_iam_role.mediaconvert_role
}

module "upload_bucket" {
  source = "./modules/s3"

  bucket_name               = "video-upload-bucket-9613"
  cors_allowed_origins      = ["http://localhost:3000"]
  enable_event_notification = true
  lambda_arn                = module.lambda_trigger.lambda_arn
  enable_versioning         = true
}

module "output_bucket" {
  source = "./modules/s3"

  bucket_name               = "video-output-bucket-9613"
  enable_versioning         = true
  enable_lifecycle          = true
  enable_event_notification = false
  lifecycle_days            = 7
}

module "lambda_trigger" {
  source        = "./modules/lambda"
  function_name = "s3-trigger-function"
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.lambda_trigger.output_path
  environment_variables = {
    MEDIACONVERT_ENDPOINT = var.mediaconvert_endpoint_url
    MEDIACONVERT_ROLE_ARN = aws_iam_role.mediaconvert_role.arn
    OUTPUT_BUCKET_ARN     = module.output_bucket.bucket_arn
  }
}


resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_trigger.lambda_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.upload_bucket.bucket_arn
}

resource "aws_iam_policy" "lambda_s3_read_object_metadata" {
  name        = "lambda-s3-read-object-metadata"
  description = "Allow lambda to read uploaded object metadata"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${module.upload_bucket.bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_read_object_metadata_attachment" {
  role       = module.lambda_trigger.lambda_role_name
  policy_arn = aws_iam_policy.lambda_s3_read_object_metadata.arn
}

resource "aws_iam_role" "mediaconvert_role" {
  name = "mediaconvert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "mediaconvert.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "mediaconvert_s3_policy" {
  role = aws_iam_role.mediaconvert_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject"]
      Resource = [
        "${module.upload_bucket.bucket_arn}/*",
        "${module.output_bucket.bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "lambda_mediaconvert_policy" {
  role = module.lambda_trigger.lambda_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["mediaconvert:CreateJob", "mediaconvert:DescribeEndpoints"]
        Resource = "*"
      },
      {
        Sid      = "AllowPassRoleToMediaConvert"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::222861903140:role/mediaconvert-role"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "mediaconvert.amazonaws.com"
          }
        }
      }
    ]
  })
}