variable "function_name" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type = string
  default = "python3.12"
}

variable "filename" {
  type = string
  description = "Path to file"
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}