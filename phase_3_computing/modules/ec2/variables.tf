variable "config" {
  description = "EC2 instance configuration from YAML"
  type = object({
    name           = string
    instance_type  = string
    instance_count = number
    team           = string
    monitoring     = bool
    ebs_optimized  = bool
    subnet_index   = optional(number)
    root_block_device = list(object({
      volume_size = number
      iops        = optional(number)
      throughput  = optional(number)
    }))
    ebs_volumes = optional(list(object({
      device_name = optional(string)
      size        = number
      iops        = optional(number)
      throughput  = optional(number)
      kms_key_id  = optional(string)
    })), [])
    instance_tags = map(string)
  })
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "environment" {
  description = "The environment to deploy resources into"
  type        = string
  default     = "dev"
}