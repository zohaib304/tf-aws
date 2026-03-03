locals {
  # ── Naming ───────────────────────────────────────────────────────────
  # A consistent prefix for all resource names in this project.
  # If project_name='my-site' and environment='dev', this becomes 'my-site-dev'
  name_prefix = "${var.project_name}-${var.environment}"
  # S3 bucket names must be globally unique across ALL of AWS.
  # Appending the AWS account ID (12 digits) guarantees no collisions.
  # Example result: 'my-site-dev-site-123456789012'
  bucket_name = "${local.name_prefix}-site-${data.aws_caller_identity.current.account_id}"
  # ── Tags ─────────────────────────────────────────────────────────────
  # Every resource in AWS should have tags. Tags help with:
  # - Cost tracking (which project spent $X this month?)
  # - Finding resources ('show me all dev resources')
  # - Automation (auto-shutdown all resources tagged Environment=dev)
  #
  # merge() combines two maps. User-supplied var.tags go first,
  # so our required tags can OVERRIDE any conflicting user tags.
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
  # ── Website Files ─────────────────────────────────────────────────────
  # A map of: filename → content-type
  # We'll use this with 'for_each' in main.tf to upload all files
  # with one resource block instead of one block per file.
  website_files = {
    "index.html" = "text/html"
    "error.html" = "text/html"
  }
  # ── CloudFront ────────────────────────────────────────────────────────
  # A logical label for the S3 origin inside CloudFront.
  # Not a URL — just an identifier string used in multiple places.
  s3_origin_id = "${local.name_prefix}-origin"
}