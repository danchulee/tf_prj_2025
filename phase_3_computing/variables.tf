variable "environment" {
  description = "The environment to deploy resources into"
  type        = string
  default     = "dev"
}

variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "playground-admin"
}