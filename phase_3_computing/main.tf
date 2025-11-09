locals {
  # VPC 정보 가져오기
  vpc_id          = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets
  vpc_cidr_block  = data.terraform_remote_state.vpc.outputs.vpc_cidr_block

  # ec2_info 디렉토리의 모든 YAML 파일 읽기
  yaml_files = fileset("${path.module}/ec2_info", "*.yaml")

  # YAML 파일들을 파싱하여 맵으로 변환
  instance_configs = {
    for file in local.yaml_files :
    trimsuffix(file, ".yaml") => yamldecode(file("${path.module}/ec2_info/${file}"))
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

# ============================================================================
# Security Group for EC2 instances (하드코딩 - 정책 강제)
# ============================================================================
# 설계 의도:
# - Egress만 허용하고 Ingress는 별도 정의 (의도치 않은 인바운드 규칙 추가 방지)
# - 변수로 노출하지 않아 실수로 잘못된 규칙을 추가하는 것 차단
# - 보안 정책을 코드 레벨에서 강제
# ============================================================================
resource "aws_security_group" "ec2_instances" {
  name_prefix = "my-instances-"
  description = "Security group for EC2 instances"
  vpc_id      = local.vpc_id

  # Egress: 모든 아웃바운드 허용 (하드코딩)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: 의도적으로 정의하지 않음 (필요 시 ALB/NLB에서 추가)

  tags = merge(local.tags, {
    Name        = "my-instances-sg"
  })
}

# EC2 Module - YAML 파일별로 for_each (admin-portal, video-encoder, api-server)
module "ec2" {
  source = "./modules/ec2"

  for_each = local.instance_configs

  # YAML 설정 전달
  config = each.value

  # VPC 정보 전달
  vpc_id          = local.vpc_id
  private_subnets = local.private_subnets
  vpc_cidr_block  = local.vpc_cidr_block

  # Security Group 및 AMI 정보 전달
  security_group_id = aws_security_group.ec2_instances.id
  ami_id            = data.aws_ami.amazon_linux_2023.id

  environment = var.environment
}
