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
    team => "https://signin.aws.amazon.com/switchrole?roleName=${team}-team-role&account=${data.aws_iam_account_alias.current.account_alias}"
  }
}
