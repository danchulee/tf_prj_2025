output "instance_ids" {
  description = "Map of instance IDs"
  value = {
    for k, v in module.ec2_instance : k => v.id
  }
}

output "instance_private_ips" {
  description = "Map of instance private IPs"
  value = {
    for k, v in module.ec2_instance : k => v.private_ip
  }
}

output "instance_arns" {
  description = "Map of instance ARNs"
  value = {
    for k, v in module.ec2_instance : k => v.arn
  }
}

output "security_group_id" {
  description = "Security Group ID for this service group"
  value       = aws_security_group.ec2.id
}
