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
