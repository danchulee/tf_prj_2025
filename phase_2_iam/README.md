# Phase 2: IAM

## 설계 철학 및 고려사항

**Team 태그 기반 접근 제어**
- IAM Policy에서 `ec2:ResourceTag/Team` 조건 사용
- 각 팀은 자신의 Team 태그가 있는 인스턴스만 SSM 접속 가능
- Least Privilege 원칙 적용

**Inline Policy 사용**
- Managed Policy 대신 Inline Policy 사용
- 각 Role과 Policy가 1:1 매핑 (재사용 계획 없음)
- Role 삭제 시 Policy도 자동 삭제 (lifecycle 일치)

**ReadOnly + SSM 권한**
- 기본적으로 ReadOnlyAccess 부여 (조회 권한)
- SSM Session Manager를 통한 인스턴스 접속 권한
- 자신이 시작한 Session만 종료/재개 가능

## 생성 리소스

**IAM Roles (3개)**
- `platform-team-role` → Team=platform 인스턴스 접속
- `backend-team-role` → Team=backend 인스턴스 접속
- `media-team-role` → Team=media 인스턴스 접속

**Inline Policies (각 Role 내장)**
- SSM 접근 권한 (Team 태그 기반 필터링)
- ReadOnlyAccess (AWS 리소스 조회)

**권한 매트릭스**
| 팀 | 접근 가능 인스턴스 | Team 태그 |
|---|---|---|
| platform | admin-portal-0 | platform |
| backend | api-server-0,1,2 | backend |
| media | video-encoder-0,1 | media |

## 제약사항

**Role Assume 조건**
- 같은 계정의 Principal만 Assume 가능
- External ID 필수 (Confused Deputy 공격 방지)

**SSM 접속 제약**
- VPC Endpoints 또는 NAT Gateway 필요
- EC2 인스턴스에 SSM Agent 설치 필수
- EC2에 IAM Instance Profile 부여 필요

**보안 고려사항**
- ReadOnly 권한이지만 민감한 정보 조회 가능 (RDS 연결 정보 등)
- Session 로그는 CloudTrail에 기록되지만 Session 내 명령어는 별도 설정 필요
