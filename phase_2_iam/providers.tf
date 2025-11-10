locals {
  region  = "ap-northeast-2"
  profile = var.profile

  is_local = var.environment == "local"
}

provider "aws" {
  region  = local.is_local ? "us-east-1" : local.region
  profile = local.is_local ? null : local.profile

  # LocalStack configuration
  access_key                  = local.is_local ? "test" : null
  secret_key                  = local.is_local ? "test" : null
  s3_use_path_style           = local.is_local ? false : null
  skip_credentials_validation = local.is_local
  skip_metadata_api_check     = local.is_local
  skip_requesting_account_id  = local.is_local

  endpoints {
    ec2            = local.is_local ? "http://127.0.0.1:4566" : null
    iam            = local.is_local ? "http://127.0.0.1:4566" : null
    ssm            = local.is_local ? "http://127.0.0.1:4566" : null
    sts            = local.is_local ? "http://127.0.0.1:4566" : null
  }
}