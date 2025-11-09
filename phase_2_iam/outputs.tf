output "team_role_arns" {
  description = "ARNs of team roles"
  value = {
    for team, role in aws_iam_role.team_role :
    team => role.arn
  }
}

output "assume_role_commands" {
  description = "Commands to assume each team role"
  value = {
    for team in local.teams :
    team => "aws sts assume-role --role-arn ${aws_iam_role.team_role[team].arn} --role-session-name ${team}-session --external-id ${team}-team-access"
  }
}
