# main.tf 

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
  tags   = merge(local.common_tags, { Name = local.bucket_name })
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all forms of public access to this bucket
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

# Upload website files with for_each
resource "aws_s3_object" "site_files" {
  for_each = local.website_files

  bucket       = aws_s3_bucket.site.id
  key          = each.key
  source       = "${path.module}/website/${each.key}"
  content_type = each.key

  # etag = a fingerprint of the file contents
  # when a index.html changed and re-apply
  # terraform knows to re-upload the file.
  etag = filemd5("${path.module}/website/${each.key}")
  tags = local.common_tags
}

#=========================
# Cloudfront
#=========================

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.name_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${local.name_prefix} static site"
  price_class     = var.cloudfront_price_class
  # When someone visits just '/' (no file specified), serve index.html
  default_root_object = "index.html"
  # ── Origin: where CloudFront fetches content from ────────────────────
  origin {
    # The S3 regional domain name (not the generic one — regional is required for OAC)
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }
  # ── Default Cache Behavior ────────────────────────────────────────────
  # Rules for how CloudFront handles requests and caching
  default_cache_behavior {
    target_origin_id = local.s3_origin_id
    # Only allow GET and HEAD (read-only — this is a static site)
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    # If someone visits http://, automatically redirect to https://
    viewer_protocol_policy = "redirect-to-https"
    # Compress files (gzip/brotli) before sending to browser — faster loads
    compress = true
    # Don't forward query strings or cookies to S3 (not needed for static files)
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0     # minimum time to cache (seconds)
    default_ttl = 3600  # cache for 1 hour by default
    max_ttl     = 86400 # never cache longer than 24 hours
  }
  # ── Error Pages ───────────────────────────────────────────────────────
  # When S3 can't find a file it returns 403 (not 404, because the bucket
  # is private — S3 hides whether the file exists or not).
  # These blocks translate that to a friendly 404 response page.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }
  # Required block — even if you're not restricting any countries
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  # Use CloudFront's built-in HTTPS certificate (covers *.cloudfront.net)
  # Free, auto-renews, no configuration needed
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cf" })
}


# This attaches the bucket policy from data.tf to our S3 bucket.
#
# Why depends_on here?
# The policy references aws_cloudfront_distribution.site.arn.
# Terraform can usually figure out dependencies automatically,
# but when a data source (not a resource) references another resource,
# it sometimes misses the dependency. We make it explicit to be safe.
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.allow_cloudfront.json
  depends_on = [
    aws_cloudfront_distribution.site,
    aws_s3_bucket_public_access_block.site,
  ]
}
