variable "mediaconvert_endpoint_url" {
  description = "Account-specific MediaConvert endpoint URL (for example, https://abcd1234.mediaconvert.us-east-1.amazonaws.com)."
  type        = string
}

variable "cli_iam_user_name" {
  description = "IAM username used for local AWS CLI commands."
  type        = string
  default     = "media_processing_pipeline"
}
