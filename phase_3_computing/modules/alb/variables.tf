variable "name" {
  description = "ALB name"
  type        = string
}

variable "config" {
  description = "ALB configuration from YAML"
  type        = any
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "target_instances" {
  description = "List of EC2 instance IDs to attach to target group"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}
