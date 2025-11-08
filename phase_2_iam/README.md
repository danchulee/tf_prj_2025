# IAM - Team-based SSM Access Control

팀별로 EC2 인스턴스에 대한 Session Manager 접근을 제어하는 IAM Policy 및 Role입니다.

## 개요

각 팀은 자신의 `Managed_Team` 태그가 있는 EC2 인스턴스에만 Session Manager로 접근할 수 있습니다.

## 생성되는 리소스

### 팀별 IAM Policy (3개)
- `SSMAccess-platform-team`
- `SSMAccess-backend-team`
- `SSMAccess-media-team`

### 팀별 IAM Role (3개)
- `SSMRole-platform-team`
- `SSMRole-backend-team`
- `SSMRole-media-team`

## 권한 매트릭스

| 팀 | 접근 가능한 인스턴스 | Managed_Team 태그 |
|---|---|---|
| platform | admin-portal-0 | platform |
| backend | api-server-0, api-server-1, api-server-2 | backend |
| media | video-encoder-0, video-encoder-1 | media |

## 사용법

### 1. Terraform 배포

```bash
cd iam
terraform init
terraform plan
terraform apply
```

### 2. Role Assume (테스트)

같은 계정의 IAM User라면 누구나 Role을 assume할 수 있습니다:

```bash
# Backend 팀 Role assume
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/SSMRole-backend-team \
  --role-session-name test-session \
  --external-id backend-team-access

# 출력된 Credentials를 환경변수로 설정
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

### 3. Session Manager 접속 테스트

**성공 케이스** (backend 팀 → api-server):
```bash
# api-server는 Managed_Team=backend
aws ssm start-session --target i-xxxxx  # ✅ 성공
```

**실패 케이스** (backend 팀 → admin-portal):
```bash
# admin-portal은 Managed_Team=platform
aws ssm start-session --target i-yyyyy  # ❌ 실패
# Error: User is not authorized to perform: ssm:StartSession on resource
```

## External ID

보안을 위해 External ID를 사용합니다:
- `platform-team-access`
- `backend-team-access`
- `media-team-access`

Role을 assume할 때 반드시 해당 팀의 External ID를 제공해야 합니다.

## 실제 운영 환경 적용

### 옵션 1: IAM User에 직접 Policy 연결

```bash
# 특정 User에게 backend 팀 Policy 부여
aws iam attach-user-policy \
  --user-name john.doe \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/SSMAccess-backend-team
```

### 옵션 2: IAM Group에 Policy 연결

```hcl
# IAM Group 생성
resource "aws_iam_group" "backend_team" {
  name = "backend-team"
}

# Policy 연결
resource "aws_iam_group_policy_attachment" "backend_ssm" {
  group      = aws_iam_group.backend_team.name
  policy_arn = aws_iam_policy.team_ssm_access["backend"].arn
}

# User를 Group에 추가
resource "aws_iam_user_group_membership" "john" {
  user = "john.doe"
  groups = [aws_iam_group.backend_team.name]
}
```

### 옵션 3: SSO/SAML 연동

```hcl
# assume_role_policy 수정
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect = "Allow"
    Principal = {
      Federated = "arn:aws:iam::ACCOUNT_ID:saml-provider/YOUR_IDP"
    }
    Action = "sts:AssumeRoleWithSAML"
    Condition = {
      StringEquals = {
        "SAML:aud" = "https://signin.aws.amazon.com/saml"
      }
    }
  }]
})
```

## 보안 고려사항

1. **Least Privilege**: 각 팀은 자신의 인스턴스만 접근 가능
2. **Session 격리**: 자신이 시작한 Session만 종료/재개 가능
3. **감사 추적**: CloudTrail로 모든 SSM 접근 로그 기록
4. **External ID**: Confused Deputy 공격 방지

## Troubleshooting

### Role Assume 실패
```
Error: AccessDenied
```

**해결**: External ID 확인
```bash
# 올바른 External ID 사용
--external-id backend-team-access
```

### Session 시작 실패
```
Error: User is not authorized to perform: ssm:StartSession
```

**해결**:
1. EC2 인스턴스의 `Managed_Team` 태그 확인
2. 올바른 팀의 Role을 assume했는지 확인
3. VPC Endpoint가 정상 동작하는지 확인
