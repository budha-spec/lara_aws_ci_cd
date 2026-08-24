variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "lara-aws-tf"
}

variable "domain_name" {
  default = "lara-tf.com"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  default = "LaraTfRDs#2026!"
  sensitive = true
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "app_key" {
  description = "Laravel application encryption key"
  type        = string
  sensitive   = true
}

variable "create_bucket" {
  type    = bool
  default = true
}