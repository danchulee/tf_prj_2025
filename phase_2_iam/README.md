# IAM - Team-based SSM Access Control

팀별로 EC2 인스턴스에 대한 Session Manager 접근을 제어하는 IAM Role과 Inline Policy입니다.

## 개요

각 팀은 자신의 `Team` 태그가 있는 EC2 인스턴스에만 Session Manager로 접근할 수 있습니다.

## 설계 특징

### Inline Policy 사용
- **Managed Policy 대신 Inline Policy 사용**
- 각 Role과 Policy가 1:1 매핑 관계
- Policy 재사용 계획 없음
- Role 삭제 시 Policy도 자동 삭제 (lifecycle 일치)

### 리소스 구조
```
platform-team-role (Role)
  └── SSMAccess (Inline Policy)

backend-team-role (Role)
  └── SSMAccess (Inline Policy)

media-team-role (Role)
  └── SSMAccess (Inline Policy)
```

## 생성되는 리소스

### 팀별 IAM Role (3개)
- `platform-team-role`
- `backend-team-role`
- `media-team-role`

### 팀별 Inline Policy (각 Role에 내장)
- `SSMAccess` (각 Role 내에서 동일한 이름 사용)

## 권한 매트릭스

| 팀 | 접근 가능한 인스턴스 | Team 태그 |
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
  --role-arn arn:aws:iam::ACCOUNT_ID:role/backend-team-role \
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
# api-server는 Team=backend
aws ssm start-session --target i-xxxxx
```

**실패 케이스** (backend 팀 → admin-portal):
```bash
# admin-portal은 Team=platform
aws ssm start-session --target i-yyyyy
# Error: User is not authorized to perform: ssm:StartSession on resource
```

## External ID

보안을 위해 External ID를 사용합니다:
- `platform-team-access`
- `backend-team-access`
- `media-team-access`

Role을 assume할 때 반드시 해당 팀의 External ID를 제공해야 합니다.

## 실제 운영 환경 적용

### 옵션 1: IAM User에게 AssumeRole 권한 부여

```hcl
# 특정 User에게 backend-team-role을 assume할 수 있는 권한 부여
resource "aws_iam_user_policy" "assume_backend_role" {
  name = "AssumeBackendRole"
  user = "john.doe"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Resource = aws_iam_role.team_role["backend"].arn
    }]
  })
}
```

### 옵션 2: IAM Group을 통한 권한 관리

```hcl
# IAM Group 생성
resource "aws_iam_group" "backend_team" {
  name = "backend-team"
}

# Group에 AssumeRole 권한 부여
resource "aws_iam_group_policy" "assume_backend_role" {
  name  = "AssumeBackendRole"
  group = aws_iam_group.backend_team.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Resource = aws_iam_role.team_role["backend"].arn
    }]
  })
}

# User를 Group에 추가
resource "aws_iam_user_group_membership" "john" {
  user = "john.doe"
  groups = [aws_iam_group.backend_team.name]
}
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
1. EC2 인스턴스의 `Team` 태그 확인
2. 올바른 팀의 Role을 assume했는지 확인
3. VPC Endpoint가 정상 동작하는지 확인
