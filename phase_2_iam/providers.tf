locals {
  region  = "ap-northeast-2"
  profile = var.profile
}

provider "aws" {
  region  = local.region
  profile = local.profile
}