terraform {
  backend "s3" {
    bucket   = "terraform"
    key      = "state"
    region   = "us-west-2"
    endpoint = "http://localhost:4566"

    skip_credentials_validation = true
    skip_metadata_api_check     = true

    force_path_style = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  s3_force_path_style = true

  endpoints {
    s3 = "http://0.0.0.0:4566"
  }
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "test-terraform-bucket"
  acl    = "private"

  tags = {
    Name        = "Test Terraform Bucket"
    Environment = "MBS"
  }
}
