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

  vpc_security_group_ids = [var.security_group_id]
  # 보안 그룹은 상위에서 생성하여 전달. 중복 생성 방지.
  create_security_group  = false

  monitoring    = var.config.monitoring
  ebs_optimized = var.config.ebs_optimized

  # Root block device - 하드코딩된 정책 적용 (EBS 암호화, gp3)
  root_block_device = {
    volume_type           = "gp3" # 강제: gp3 사용
    volume_size           = try(var.config.root_block_device[0].volume_size, 30)
    encrypted             = true # 강제: 암호화 필수
    delete_on_termination = true
    iops                  = try(var.config.root_block_device[0].iops, null)
    throughput            = try(var.config.root_block_device[0].throughput, null)
  }

  # Additional EBS volumes - 암호화 및 gp3 강제 (있는 경우에만)
  ebs_volumes = {
    for idx, ebs in try(var.config.ebs_volumes, []) :
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

  # T 시리즈 Credit 설정 - 하드코딩 (비용 통제) - T 타입인 경우에만
  cpu_credits = startswith(var.config.instance_type, "t") ? "standard" : null

  # IAM Instance Profile - Session Manager
  create_iam_instance_profile = true
  iam_role_description        = "IAM role for ${var.config.name}-${each.key}"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = merge(
    {
      Terraform      = "true"
      Environment    = "dev"
      Managed_Team   = var.config.team
      InstanceIndex  = each.key
      InstanceFamily = var.config.name
    },
    var.config.instance_tags
  )
}
