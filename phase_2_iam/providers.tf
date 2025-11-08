locals {
  region  = "ap-northeast-2"
  profile = "playground-admin"

  account_id = {
    local = "123456789012"
  }

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
    apigateway     = local.is_local ? "http://127.0.0.1:4566" : null
    apigatewayv2   = local.is_local ? "http://127.0.0.1:4566" : null
    cloudformation = local.is_local ? "http://127.0.0.1:4566" : null
    cloudwatch     = local.is_local ? "http://127.0.0.1:4566" : null
    dynamodb       = local.is_local ? "http://127.0.0.1:4566" : null
    ec2            = local.is_local ? "http://127.0.0.1:4566" : null
    es             = local.is_local ? "http://127.0.0.1:4566" : null
    elasticache    = local.is_local ? "http://127.0.0.1:4566" : null
    firehose       = local.is_local ? "http://127.0.0.1:4566" : null
    iam            = local.is_local ? "http://127.0.0.1:4566" : null
    kinesis        = local.is_local ? "http://127.0.0.1:4566" : null
    lambda         = local.is_local ? "http://127.0.0.1:4566" : null
    rds            = local.is_local ? "http://127.0.0.1:4566" : null
    redshift       = local.is_local ? "http://127.0.0.1:4566" : null
    route53        = local.is_local ? "http://127.0.0.1:4566" : null
    s3             = local.is_local ? "http://s3.localhost.localstack.cloud:4566" : null
    secretsmanager = local.is_local ? "http://127.0.0.1:4566" : null
    ses            = local.is_local ? "http://127.0.0.1:4566" : null
    sns            = local.is_local ? "http://127.0.0.1:4566" : null
    sqs            = local.is_local ? "http://127.0.0.1:4566" : null
    ssm            = local.is_local ? "http://127.0.0.1:4566" : null
    stepfunctions  = local.is_local ? "http://127.0.0.1:4566" : null
    sts            = local.is_local ? "http://127.0.0.1:4566" : null
  }
}