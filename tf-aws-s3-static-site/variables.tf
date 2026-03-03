variable "aws_region" {
  description = "The AWS region where resourcese will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A short name use to prefix all resources name in this project."
  type        = string
  default     = "my-site"
}

variable "environment" {
  description = "Which environment this is: dev, staging or prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be on of: dev, staging, prod."
  }
}

variable "cloudfront_price_class" {
  description = "Which cloudfront edge location to use PriceClass_100 = cheapest (US/EU only)"
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Extra tags to apply to every resources"
  type        = map(string)
  default     = {}
}