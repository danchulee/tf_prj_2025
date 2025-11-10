variable "environment" {
  description = "The environment to deploy resources into"
  type        = string
  default     = "dev"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "jw-lee-vpc"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "profile" {
  description = "The AWS CLI profile to use"
  type        = string
  default     = "playground-admin"
}