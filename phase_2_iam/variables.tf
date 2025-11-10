variable "environment" {
  description = "The environment to deploy resources into"
  type        = string
  default     = "dev"
}

variable "teams" {
  description = "Map of teams for IAM policies"
  type        = list(string)
  default     = ["platform", "backend", "media"]
}