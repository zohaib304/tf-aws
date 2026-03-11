output "images_bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "violations_bucket_name" {
  value = aws_s3_bucket.violations.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.safety_log.name
}

output "upload_command" {
  value = "aws s3 cp your-image.jpg s3://${aws_s3_bucket.images.bucket}/"
}
