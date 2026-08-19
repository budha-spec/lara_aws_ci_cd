terraform {

  backend "s3" {

    bucket = "lara-app-prod-storage"

    key = "terraform/state.tfstate"

    region = "us-east-1"

    encrypt = true

    use_lockfile = true

  }

}