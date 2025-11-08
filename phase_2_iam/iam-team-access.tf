# 팀별 SSM 접근 제어를 위한 IAM Policy
# 각 팀은 자신의 Managed_Team 태그가 있는 인스턴스만 접근 가능

locals {
  teams = toset(["platform", "backend", "media"])
}

# 팀별 IAM Policy Document
data "aws_iam_policy_document" "team_ssm_access" {
  for_each = local.teams

  # SSM 기본 권한
  statement {
    sid    = "SSMBasicPermissions"
    effect = "Allow"
    actions = [
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssm:DescribeInstanceProperties",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  # 자신의 팀 태그가 있는 인스턴스만 Session 시작 가능
  statement {
    sid    = "StartSessionOnTeamInstances"
    effect = "Allow"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ec2:*:*:instance/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Managed_Team"
      values   = [each.key]
    }
  }

  # SSM Session Document 접근 (기본 Session Manager 설정)
  statement {
    sid    = "AllowSessionDocument"
    effect = "Allow"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ssm:*:*:document/AWS-StartSSHSession",
      "arn:aws:ssm:*:*:document/SSM-SessionManagerRunShell"
    ]
  }

  # 자신의 Session만 종료/재개 가능
  statement {
    sid    = "ManageOwnSessions"
    effect = "Allow"
    actions = [
      "ssm:TerminateSession",
      "ssm:ResumeSession"
    ]
    resources = [
      "arn:aws:ssm:*:*:session/*"
    ]
    condition {
      test     = "StringLike"
      variable = "ssm:resourceTag/aws:ssmmessages:session-id"
      values   = ["$${aws:userid}"]
    }
  }
}

# 팀별 IAM Policy 생성
resource "aws_iam_policy" "team_ssm_access" {
  for_each = local.teams

  name        = "SSMAccess-${each.key}-team"
  description = "Allow SSM access to ${each.key} team instances only"
  policy      = data.aws_iam_policy_document.team_ssm_access[each.key].json

  tags = {
    Team      = each.key
    Terraform = "true"
  }
}

# 팀별 IAM Role 생성 (옵션)
# 실제 사용 시 assume_role_policy를 조직에 맞게 수정 필요
resource "aws_iam_role" "team_ssm_role" {
  for_each = local.teams

  name = "SSMRole-${each.key}-team"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # AWS = "arn:aws:iam::ACCOUNT_ID:root"  # 실제 환경에 맞게 수정
          # Federated = "arn:aws:iam::ACCOUNT_ID:saml-provider/YOUR_SAML_PROVIDER"
          Service = "ec2.amazonaws.com"  # 테스트용, 실제로는 위 Principal 사용
        }
      }
    ]
  })

  tags = {
    Team      = each.key
    Terraform = "true"
  }
}

# Policy를 Role에 연결
resource "aws_iam_role_policy_attachment" "team_ssm_access" {
  for_each = local.teams

  role       = aws_iam_role.team_ssm_role[each.key].name
  policy_arn = aws_iam_policy.team_ssm_access[each.key].arn
}

# Outputs
output "team_ssm_policy_arns" {
  description = "ARNs of team-specific SSM access policies"
  value = {
    for team, policy in aws_iam_policy.team_ssm_access :
    team => policy.arn
  }
}

output "team_ssm_role_arns" {
  description = "ARNs of team-specific SSM access roles"
  value = {
    for team, role in aws_iam_role.team_ssm_role :
    team => role.arn
  }
}
