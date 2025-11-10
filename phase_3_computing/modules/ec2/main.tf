locals {
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

# EC2 Instances - instance_count 만큼 for_each로 생성
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.1.4"

  # instance_count 만큼 인스턴스 생성
  for_each = toset([for idx in range(var.config.instance_count) : tostring(idx)])

  name          = "${var.config.name}-${each.key}"
  instance_type = var.config.instance_type

  ami = var.ami_id

  # 각 인스턴스를 존별 서브넷에 분산 배치
  subnet_id = var.private_subnets[
    coalesce(var.config.subnet_index, abs(parseint(substr(md5("${var.config.name}-${each.key}"), 0, 8), 16)) % length(var.private_subnets))
  ]

  vpc_security_group_ids = [aws_security_group.ec2.id]
  # 보안 그룹은 security_group.tf에서 생성. 중복 생성 방지.
  create_security_group  = false

  monitoring    = var.config.monitoring
  ebs_optimized = var.config.ebs_optimized

  # ============================================================================
  # Root block device - 하드코딩된 정책 적용 (보안 및 비용 최적화)
  # ============================================================================
  # 설계 의도:
  # - encrypted = true: 규정 준수, 데이터 보안 (변경 불가)
  # - volume_type = gp3: 비용 최적화 - gp2 대비 20% 저렴 (변경 불가)
  # - volume_size: YAML에서 조정 가능 (유연성 제공)
  # ============================================================================
  root_block_device = {
    volume_type           = "gp3" # 강제: gp3 사용
    volume_size           = try(var.config.root_block_device[0].volume_size, 30)
    encrypted             = true # 강제: 암호화 필수
    delete_on_termination = true
    iops                  = try(var.config.root_block_device[0].iops, null)
    throughput            = try(var.config.root_block_device[0].throughput, null)
  }

  # ============================================================================
  # Additional EBS volumes - 암호화 및 gp3 강제 (있는 경우에만)
  # ============================================================================
  ebs_volumes = {
    for idx, ebs in try(var.config.ebs_volumes, []) :
    # f부터 시작하는 디바이스 네이밍 규칙 적용. 중복 방지 위해 인덱스 사용.
    coalesce(ebs.device_name, "/dev/sd${substr("fghijklmnop", idx, 1)}") => {
      device_name = coalesce(ebs.device_name, "/dev/sd${substr("fghijklmnop", idx, 1)}")
      type        = "gp3" # 강제: gp3 사용
      size        = ebs.size
      encrypted   = true # 강제: 암호화 필수
      iops        = try(ebs.iops, null)
      throughput  = try(ebs.throughput, null)
      kms_key_id  = try(ebs.kms_key_id, null)
    }
  }

  # ============================================================================
  # T 시리즈 Credit 설정 - 하드코딩 (비용 통제)
  # ============================================================================
  # 설계 의도:
  # - cpu_credits = "standard": unlimited 모드로 인한 예상치 못한 비용 발생 방지
  # - T 타입만 적용, 다른 타입은 null
  # ============================================================================
  cpu_credits = startswith(var.config.instance_type, "t") ? "standard" : null

  # ============================================================================
  # IAM Instance Profile - 공유 Profile 사용 (하드코딩 - 정책 강제)
  # ============================================================================
  # 설계 의도:
  # - iam.tf에서 생성한 공통 Profile 사용
  # - create_iam_instance_profile = false로 설정하여 중복 생성 방지
  # - iam_instance_profile에 공유 Profile 이름 전달
  # ============================================================================
  create_iam_instance_profile = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm_profile.name

  tags = merge(local.tags, merge(
    {
      Team   = var.config.team
      InstanceIndex  = each.key
      InstanceFamily = var.config.name
    },
    var.config.instance_tags
  ))
}
