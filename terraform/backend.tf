terraform {

  backend "s3" {

    bucket = "lara-aws-tf-prod"

    key = "terraform/state.tfstate"

    region = "us-east-1"

    encrypt = true

    use_lockfile = true

  }

}