variable "aws_region" {
    default = "us-east-1"
}

variable "tag_name" {
  default = "lara-aws"
}

variable "managed_by" {
  default = "Terraform"
}

variable "env" {
  default = "prod"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "db_name" {
  default = "lara_aws_db"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  default = "LaraTfAws@2026"
}