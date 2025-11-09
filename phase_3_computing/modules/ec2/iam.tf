# ============================================================================
# 서비스군별 공유 IAM Instance Profile (하드코딩 - 정책 강제)
# ============================================================================
# 설계 의도:
# - 같은 서비스군(admin-portal, video-encoder, api-server)의 인스턴스들이 Profile 공유
# - 인스턴스별 Role/Profile 생성 방지 (리소스 중복 제거)
# - 서비스군별로 분리하여 향후 서비스별 추가 권한 확장 가능
#   (예: video-encoder에만 S3 접근, api-server에만 DynamoDB 접근)
# - 현재는 모든 서비스군이 SSM 정책만 사용하지만, 확장성 고려한 설계
# ============================================================================
resource "aws_iam_role" "ec2_ssm_role" {
  name        = "ec2-ssm-role-${var.config.name}"
  description = "Shared IAM role for ${var.config.name} EC2 instances with SSM access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.tags, {
    Name           = "ec2-ssm-role-${var.config.name}"
    InstanceFamily = var.config.name
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile-${var.config.name}"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Name           = "ec2-ssm-profile-${var.config.name}"
    Terraform      = "true"
    Environment    = "dev"
    InstanceFamily = var.config.name
  }
}
