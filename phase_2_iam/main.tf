# 팀별 SSM 접근 제어를 위한 IAM Policy 및 Role
# 각 팀은 자신의 Team 태그가 있는 인스턴스만 접근 가능

# 현재 계정 ID 가져오기
data "aws_caller_identity" "current" {}

locals {
  teams      = toset(["platform", "backend", "media"])
  account_id = data.aws_caller_identity.current.account_id
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
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
      variable = "ssm:resourceTag/Team"
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

  # 자신이 시작한 Session만 종료/재개 가능
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
  }
}

# 팀별 IAM Role 생성
# 같은 계정의 모든 IAM User/Role이 assume 가능
resource "aws_iam_role" "team_role" {
  for_each = local.teams

  name        = "${each.key}-team-role"
  description = "Role for ${each.key} team"

  # 같은 계정의 모든 Principal이 assume 가능 (테스트용)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${each.key}-team-access"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Team = each.key
  })
}

# Inline Policy로 직접 연결 (1:1 매핑, 재사용 없음)
resource "aws_iam_role_policy" "team_ssm_access" {
  for_each = local.teams

  name   = "SSMAccess"
  role   = aws_iam_role.team_role[each.key].id
  policy = data.aws_iam_policy_document.team_ssm_access[each.key].json
}
