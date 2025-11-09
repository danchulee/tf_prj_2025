# Computing Infrastructure

EC2 인스턴스를 YAML 기반으로 선언적으로 관리하는 Terraform 모듈입니다.

## 아키텍처 개요

```
computing/
├── main.tf                          # 1st for_each: YAML 파일별 모듈 호출
├── data.tf                          # VPC remote state, AMI 데이터 소스
├── ec2_info/                        # 서비스별 EC2 설정 (YAML)
│   ├── admin-portal.yaml
│   ├── video-encoder.yaml
│   └── api-server.yaml
└── modules/
    └── ec2/
        ├── main.tf                  # 2nd for_each: instance_count만큼 인스턴스 생성
        ├── variables.tf             # 모듈 입력 변수
        └── outputs.tf               # 모듈 출력 (instance IDs, IPs, ARNs)
```

## 설계 철학 및 고려사항

### 1. 정책 강제 vs 유연성 분리

**문제**: 보안/비용 정책은 강제해야 하지만, 서비스별 요구사항은 유연하게 대응해야 함

**해결**:
- **하드코딩된 정책 (modules/ec2/main.tf에 강제)**:
  - EBS 암호화: `encrypted = true` (보안 정책)
  - EBS 볼륨 타입: `type = "gp3"` (비용 최적화 - gp2 대비 20% 저렴)
  - T 시리즈 CPU Credits: `cpu_credits = "standard"` (비용 통제 - unlimited 모드 방지)
  - Root volume 삭제: `delete_on_termination = true` (리소스 정리)

- **YAML로 커스터마이징 가능**:
  - 인스턴스 타입 (`instance_type`)
  - 볼륨 크기 (`volume_size`)
  - IOPS/Throughput (성능 튜닝)
  - 모니터링 옵션 (`monitoring`)
  - 팀별 태그 (`team`, `instance_tags`)

**이유**: 변수로 노출하면 실수로 정책을 위반할 수 있음. 정책은 코드에 박아두고 YAML에서는 변경 불가능하도록 설계.

### 2. 2단계 for_each 구조

**문제**: 서비스별로 다른 개수의 인스턴스를 생성하면서도 확장성을 유지해야 함

**해결**:
```hcl
# 1단계: computing/main.tf
module "ec2" {
  for_each = local.instance_configs  # admin-portal, video-encoder, api-server
  ...
}

# 2단계: modules/ec2/main.tf
module "ec2_instance" {
  for_each = toset([for idx in range(var.config.instance_count) : tostring(idx)])
  ...
}
```

**생성되는 리소스 구조**:
```
module.ec2["admin-portal"].module.ec2_instance["0"]     # admin-portal-0
module.ec2["video-encoder"].module.ec2_instance["0"]    # video-encoder-0
module.ec2["video-encoder"].module.ec2_instance["1"]    # video-encoder-1
module.ec2["api-server"].module.ec2_instance["0"]       # api-server-0
module.ec2["api-server"].module.ec2_instance["1"]       # api-server-1
module.ec2["api-server"].module.ec2_instance["2"]       # api-server-2
```

**장점**:
- YAML 파일별로 독립적인 모듈 (admin-portal, video-encoder, api-server)
- 각 서비스별로 다른 instance_count 설정 가능
- Terraform state가 명확하게 분리됨

### 3. 수평적 확장 (Horizontal Pod Autoscaling 개념 차용)

**문제**: 트래픽 증가 시 인스턴스를 쉽게 추가/제거할 수 있어야 함

**해결**:
```yaml
# ec2_info/api-server.yaml
instance_count: 3  # 이 값만 변경하면 됨
```

**이유**:
- Kubernetes HPA처럼 간단하게 스케일링
- `terraform apply` 한 번으로 인스턴스 추가/제거
- 인프라 변경을 코드 1줄로 완료

### 4. 워크로드별 인스턴스 타입 분리

**고민**: T, C, M 시리즈 중 어떤 워크로드에 어떤 타입을 사용할까?

**결정**:
- **T3a (Burstable)**: `admin-portal`
  - 내부 관리 도구, 트래픽 예측 가능
  - 평소엔 낮은 CPU, 가끔 버스트 필요
  - 비용 효율적 (credits 관리 필요)

- **C7i (Compute Optimized)**: `video-encoder`
  - CPU 집약적 작업 (영상 인코딩)
  - 지속적인 고성능 CPU 필요
  - EBS 추가 볼륨으로 임시 작업 공간 제공

- **M7i-flex (Memory Optimized)**: `api-server`
  - 메모리 집약적 (캐싱, 세션 관리)
  - CPU/메모리 균형 필요
  - 가장 많은 인스턴스 수 필요 (트래픽 분산)

**T 시리즈 특별 처리**:
```hcl
cpu_credits = startswith(var.config.instance_type, "t") ? "standard" : null
```
- T 타입만 `standard` 모드 강제
- unlimited 모드는 예상치 못한 비용 발생 가능성 있음

### 5. 서브넷 분산 배치

**문제**: 인스턴스를 여러 AZ에 분산 배치하여 고가용성 확보

**해결**:
```hcl
# Option 1: YAML에서 명시적 지정
subnet_index: 0  # 0=AZ-1, 1=AZ-2, 2=AZ-3

# Option 2: 자동 분산 (해시 기반)
subnet_id = var.private_subnets[
  try(var.config.subnet_index,
      abs(tonumber(substr(md5("${var.config.name}-${each.key}"), 0, 8), 16)))
      % length(var.private_subnets)
]
```

**이유**:
- 인스턴스 이름 기반 MD5 해싱으로 결정론적 분산
- 같은 이름이면 항상 같은 서브넷 (재생성 시에도 동일)
- 필요하면 YAML에서 수동 지정 가능

### 6. EBS 디바이스 네이밍 전략

**문제**: 추가 EBS 볼륨의 디바이스명을 어떻게 할당할까?

**해결**:
```hcl
device_name = try(ebs.device_name, "/dev/sd${substr("fghijklmnop", idx, 1)}")
```

**규칙**:
- `/dev/sda-e`: 예약됨 (루트 볼륨, 인스턴스 스토어)
- `/dev/sdf-p`: 추가 EBS 볼륨용
- YAML에서 명시 안 하면 순차적 할당 (f, g, h, ...)
- 충돌 방지를 위해 순차 할당 (랜덤 X)

### 7. IAM Role - Session Manager 통합

**문제**: SSH 키 없이 안전하게 인스턴스 접속

**해결**:
```hcl
create_iam_instance_profile = true
iam_role_policies = {
  AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**장점**:
- SSH 키 관리 불필요
- AWS Console/CLI에서 Session Manager로 접속
- 접속 로그 자동 기록 (감사 추적)
- Private 서브넷 인스턴스도 VPC Endpoint 통해 접속 가능

### 8. 태그 전략

**자동 태그** (모든 인스턴스):
```hcl
tags = {
  Terraform      = "true"
  Environment    = "dev"
  Team   = var.config.team          # YAML에서 정의
  InstanceIndex  = each.key                 # 0, 1, 2, ...
  InstanceFamily = var.config.name          # admin-portal, video-encoder, ...
}
```

**커스텀 태그** (YAML `instance_tags`):
```yaml
instance_tags:
  Name: video-encoder
  Workload: encoding
  InstanceFamily: compute-optimized
```

**이유**:
- `InstanceFamily`로 같은 서비스군 식별
- `InstanceIndex`로 개별 인스턴스 구분
- 비용 추적, 리소스 관리 용이

### 9. 모듈 재사용성

**문제**: 다른 환경(dev, staging, prod)에서도 사용 가능해야 함

**해결**:
- `modules/ec2`는 순수 모듈 (환경 무관)
- 환경별 설정은 `computing/main.tf`에서 주입
- YAML 파일만 환경별로 분리 가능

**확장 예시**:
```
computing/
├── ec2_info/
│   ├── dev/
│   │   └── *.yaml
│   ├── staging/
│   │   └── *.yaml
│   └── prod/
│       └── *.yaml
```

### 10. 보안 그룹 설계

**현재**: 모든 EC2가 하나의 보안 그룹 공유

**이유**:
- 초기 단계에서는 단순하게 시작
- Egress: 모든 아웃바운드 허용 (인터넷 접근)
- Ingress: 별도 정의 필요 (ALB/NLB에서 추가 예정)

**향후 개선**:
- 서비스별 보안 그룹 분리
- Least privilege 원칙 적용

## 사용법

### 새 서비스 추가

1. **YAML 파일 생성**:
```yaml
# ec2_info/new-service.yaml
name: new-service
instance_type: t3a.medium
instance_count: 2
team: backend
monitoring: true
ebs_optimized: true
root_block_device:
  - volume_size: 40
instance_tags:
  Name: new-service
  Workload: api
```

2. **Terraform 실행**:
```bash
cd computing
terraform plan
terraform apply
```

자동으로 `new-service-0`, `new-service-1` 인스턴스가 생성됩니다.

### 스케일 아웃

```yaml
# ec2_info/api-server.yaml
instance_count: 5  # 3 -> 5로 변경
```

```bash
terraform apply  # api-server-3, api-server-4 추가 생성
```

### 스케일 인

```yaml
instance_count: 2  # 3 -> 2로 변경
```

```bash
terraform apply  # api-server-2 제거
```

⚠️ **주의**: for_each는 인덱스가 높은 것부터 제거됩니다.

## LocalStack 테스트

```bash
# 로컬 환경 테스트
ENV=local make init
ENV=local make plan
ENV=local make apply
```

`ENV=local`이면 `tflocal` 사용, 아니면 `terraform` 사용합니다.

## 제약사항 및 트레이드오프

### 제약사항
1. **정책 변경 불가**: EBS 암호화, gp3, T 시리즈 credits는 코드 수정 필요
2. **인스턴스 순서**: for_each 특성상 마지막 인덱스부터 제거됨
3. **보안 그룹 공유**: 모든 인스턴스가 같은 보안 그룹 사용

### 트레이드오프
- **유연성 vs 정책 강제**: 정책 강제를 선택 (보안/비용 우선)
- **단순성 vs 세분화**: 단순한 구조 선택 (초기 단계)
- **재사용성 vs 최적화**: 재사용성 선택 (모듈 구조)

## 참고 자료

- [Terraform AWS EC2 Module](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws)
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [EBS Volume Types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
