# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "ap-northeast-1"
}

variable "custom_search_cx" {
  default = ""
}

variable "custom_search_key" {
  default = ""
}
