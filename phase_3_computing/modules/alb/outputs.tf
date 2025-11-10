output "alb_id" {
  description = "The ID of the load balancer"
  value       = module.alb.id
}

output "alb_arn" {
  description = "The ARN of the load balancer"
  value       = module.alb.arn
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.alb.dns_name
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value       = module.alb.target_groups
}

output "security_group_id" {
  description = "Security Group ID of the ALB"
  value       = module.alb.security_group_id
}
