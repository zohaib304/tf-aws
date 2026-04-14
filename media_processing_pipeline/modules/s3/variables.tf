variable "bucket_name" {
  type = string
  description = "Name of the S3 bucket"
}

variable "enable_versioning" {
  type = bool
  default = true
}

variable "enable_lifecycle" {
  type = bool
  default = false
}

variable "lifecycle_days" {
  type    = number
  default = 30
}

variable "cors_allowed_origins" {
  type    = list(string)
  default = []
}

variable "enable_event_notification" {
  type    = bool
  default = false
}

variable "lambda_arn" {
  type        = string
  description = "Lambda ARN to receive S3 ObjectCreated notifications"
  default     = null
}