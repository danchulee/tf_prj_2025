# Phase 3: Computing

## 설계 철학 및 고려사항

**보안과 비용은 강제, 스펙은 유연하게**
- EBS 암호화(encrypted=true), gp3 볼륨, T 시리즈 credits(standard) 하드코딩
- 인스턴스 타입, 개수, 볼륨 크기는 YAML로 커스터마이징

**2단계 for_each 구조**
- 1단계: YAML 파일별 모듈 호출 (서비스군 단위)
- 2단계: instance_count만큼 인스턴스 생성 (개별 인스턴스)

**워크로드별 인스턴스 타입 최적화**
- **T3a (Burstable)**: admin-portal - 내부 관리 도구, 트래픽 예측 가능
- **C7i (Compute Optimized)**: video-encoder - CPU 집약적 인코딩 작업
- **M7i-flex (Memory Optimized)**: api-server - 메모리 집약적 캐싱/세션 관리

**YAML 기반 선언적 관리**
- HPA(Horizontal Pod Autoscaling) 개념 차용
- instance_count만 변경하면 자동 스케일링

**ALB를 통한 트래픽만 수신**
- EC2 Security Group: 기본적으로 Egress만 허용
- ALB가 있는 서비스만 ALB Security Group을 소스로 하는 Ingress 규칙 추가

## 생성 리소스

**EC2 인스턴스 (3개)**
- admin-portal-0 (t3a.medium, Team=platform)
- video-encoder-0 (c7i.large, Team=media)
- api-server-0 (m7i-flex.large, Team=backend)

**ALB (2개)**
- admin-portal-alb (Internal) - admin-portal 인스턴스 타겟
- api-server-alb (Internet-facing) - api-server 인스턴스 타겟

**Security Groups**
- 서비스군별 EC2 Security Group (Egress only)
- ALB Security Group (HTTP 80 인바운드)
- ALB→EC2 Ingress 규칙 (ALB SG만 허용)

**IAM Instance Profile**
- 서비스군별 Instance Profile
- SSM 접속 권한 (AmazonSSMManagedInstanceCore)

**User Data**
- Nginx 자동 설치 및 구성
- `/health` 엔드포인트 (ALB Health Check)

## 제약사항

**정책 변경 불가**
- EBS 암호화, gp3 볼륨, T 시리즈 credits는 코드 수정 필요
- Security Group Egress only 정책 변경 불가

**인스턴스 순서**
- for_each 특성상 스케일 인 시 마지막 인덱스부터 제거됨
- 예: instance_count 3→2 변경 시 인덱스 2번 제거

**HTTP만 사용**
- 테스트 환경으로 ACM 인증서 미사용
- HTTP(80)만 사용 (HTTPS 필요 시 ACM 인증서 및 Listener 추가 필요)

**ALB 테스트 제약**
- api-server-alb는 Internet-facing이지만 allow_cidrs 설정 필요
- 본인 IP를 api-server.yaml의 allow_cidrs에 추가해야 접속 가능
