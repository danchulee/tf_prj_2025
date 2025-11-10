locals {
  # VPC 정보 가져오기
  vpc_id          = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets
  vpc_cidr_block  = data.terraform_remote_state.vpc.outputs.vpc_cidr_block

  # server_info 디렉토리의 모든 YAML 파일 읽기
  yaml_files = fileset("${path.module}/server_info", "*.yaml")

  # YAML 파일들을 파싱하여 맵으로 변환
  instance_configs = {
    for file in local.yaml_files :
    trimsuffix(file, ".yaml") => yamldecode(file("${path.module}/server_info/${file}"))
  }

  # ALB가 필요한 서비스만 필터링
  alb_configs = {
    for name, config in local.instance_configs :
    name => config.alb
    if try(config.alb.enabled, false) == true
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
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

  # AMI 정보 전달
  ami_id = data.aws_ami.amazon_linux_2023.id

  environment = var.environment
}

# ============================================================================
# Application Load Balancer (ALB가 enabled된 서비스만 생성)
# ============================================================================
module "alb" {
  source = "./modules/alb"

  for_each = local.alb_configs

  name = each.key
  config = each.value

  # VPC 정보 전달
  vpc_id          = local.vpc_id
  private_subnets = local.private_subnets
  public_subnets  = data.terraform_remote_state.vpc.outputs.public_subnets
  vpc_cidr_block  = local.vpc_cidr_block

  # EC2 인스턴스 ID 목록 전달 (해당 서비스의 모든 인스턴스)
  target_instances = values(module.ec2[each.key].instance_ids)

  environment = var.environment
}

# ============================================================================
# Security Group Rule: ALB → EC2 (ALB가 있는 서비스만)
# ============================================================================
# ALB Security Group에서 EC2로의 인바운드 트래픽 허용
# 각 서비스군의 Security Group에 해당 ALB의 규칙만 추가
resource "aws_security_group_rule" "alb_to_ec2" {
  for_each = local.alb_configs

  type                     = "ingress"
  from_port                = try(each.value.target_port, 80)
  to_port                  = try(each.value.target_port, 80)
  protocol                 = "tcp"
  source_security_group_id = module.alb[each.key].security_group_id
  security_group_id        = module.ec2[each.key].security_group_id
  description              = "Allow traffic from ${each.key} ALB"
}
