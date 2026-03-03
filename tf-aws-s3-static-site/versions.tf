# variables.tf
terraform {
  required_version = ">= 1.14.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.34.0"
    }
  }

  # REMOTE STATE BACKEND
  # This tells Terraform to save its state file in S3
  # instead of locally on you laptop
  backend "s3" {
    bucket       = "tf-state-222861903140"
    key          = "s3-static-site/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}