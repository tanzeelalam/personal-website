provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-resources-personal-website"
    region = "us-east-1"
    key = "github-actions/terraform.tfstate"
    encrypt = true
    use_lockfile = "terraform-resources-personal-website"
  }
}