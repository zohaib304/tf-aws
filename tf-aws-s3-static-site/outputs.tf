# outputs.tf
output "website_url" {
  description = "The public HTTPS URL of your website — open this in a browser!"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}
output "cloudfront_distribution_id" {
  description = "The CloudFront distribution ID — needed to invalidate the cache"
  value       = aws_cloudfront_distribution.site.id
}
output "s3_bucket_name" {
  description = "The name of your S3 bucket"
  value       = aws_s3_bucket.site.id
}
output "s3_bucket_arn" {
  description = "The ARN of your S3 bucket — used in IAM policies"
  value       = aws_s3_bucket.site.arn
}
