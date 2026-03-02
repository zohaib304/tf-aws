# variables.tf

variable "aws_region" {
  description = "AWS Region to deploy VPC"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name tag applied to the VPC and all child resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR block for public subnet (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR block for private subnet (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "List of AZs to deploy subnet into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Set to false to skip NAT Gateway"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Map of additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
