# ============================================================================
# 서비스군별 Security Group (하드코딩 - 정책 강제)
# ============================================================================
# 설계 의도:
# - 각 서비스군(admin-portal, video-encoder, api-server)별로 독립적인 SG 생성
# - Egress만 허용하고 Ingress는 별도 정의 (의도치 않은 인바운드 규칙 추가 방지)
# - ALB→EC2 규칙은 main.tf에서 aws_security_group_rule로 추가
# - 서비스 삭제 시 SG도 함께 정리됨 (모듈 캡슐화)
# ============================================================================
resource "aws_security_group" "ec2" {
  name_prefix = "${var.config.name}-"
  description = "Security group for ${var.config.name} EC2 instances"
  vpc_id      = var.vpc_id

  # Egress: 모든 아웃바운드 허용 (하드코딩)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: 의도적으로 정의하지 않음 (필요 시 외부에서 aws_security_group_rule로 추가)

  tags = merge(local.tags, {
    Name = "${var.config.name}-sg"
  })
}
