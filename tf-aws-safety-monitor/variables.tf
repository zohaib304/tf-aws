variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource name"
  type        = string
  default     = "safety-monitor"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address to receive safety violation alerts"
  type        = string
}

variable "confidence_threshold" {
  description = "Minimum Rekognition confidence score (0-100)"
  type        = number
  default     = 80
}

