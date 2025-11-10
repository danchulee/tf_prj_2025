# Phase 1: Network

## 설계 철학 및 고려사항

**고가용성 아키텍처**
- 3개 AZ에 Public/Private Subnet 각 1개씩 배치
- NAT Gateway를 통한 Private 서브넷 인터넷 아웃바운드

**VPC Endpoints를 통한 비용 절감**
- SSM, EC2 Messages, SSM Messages용 Interface Endpoint 구성
- Private 서브넷의 EC2 인스턴스가 NAT Gateway 없이 SSM 접속 가능
- 데이터 전송 비용 절감 및 보안 강화

**Terraform 공식 모듈 활용**
- [terraform-aws-modules/vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- 완전한 옵션 지원 및 검증된 구조

## 생성 리소스

**네트워크 기본 구성**
- VPC (10.50.0.0/16)
- Public Subnets: 3개 (각 AZ당 1개)
- Private Subnets: 3개 (각 AZ당 1개)
- Internet Gateway: 1개
- NAT Gateway: 1개 (AZ-1)

**라우팅**
- Public Route Table (IGW 연결)
- Private Route Tables (NAT Gateway 연결)

**VPC Endpoints**
- com.amazonaws.ap-northeast-2.ssm
- com.amazonaws.ap-northeast-2.ec2messages
- com.amazonaws.ap-northeast-2.ssmmessages

## 제약사항

**고정된 설계**
- CIDR: 10.50.0.0/16 (변경 시 코드 수정 필요)
- Region: ap-northeast-2 (서울)
- AZ 개수: 3개 고정

**비용 고려사항**
- NAT Gateway: 1개만 사용 (단일 장애점 존재)
- 고가용성 필요 시 각 AZ별 NAT Gateway 추가 필요

**VPC Endpoints 제약**
- Interface Endpoint는 시간당 과금
- 트래픽 비용 vs Endpoint 비용 트레이드오프 고려 필요
