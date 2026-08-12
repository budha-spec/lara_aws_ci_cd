terraform {
  backend "s3" {
    bucket       = "lara-aws-prod"
    key          = "terraform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true 
  }
}