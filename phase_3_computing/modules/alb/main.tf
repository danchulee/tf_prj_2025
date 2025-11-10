locals {
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

# ============================================================================
# Application Load Balancer (공식 모듈 사용)
# ============================================================================
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.2.0"

  name     = var.config.name
  vpc_id   = var.vpc_id
  internal = try(var.config.internal, true)  # internal = true면 Internal ALB, false면 Internet-facing
  subnets  = try(var.config.internal, true) ? var.private_subnets : var.public_subnets

  # Security Group
  # allow_cidrs 리스트의 각 CIDR에 대해 HTTP(80) ingress rule 생성
  # 보안 참고: ACM 인증서 생성 후 HTTP(80) -> HTTPS(443) 리다이렉트 구성 필요
  #           보안상 HTTPS(443)만 허용하고 HTTP 요청은 HTTPS로 리다이렉트하는 것이 권장됨
  security_group_ingress_rules = {
    for idx, cidr in try(var.config.allow_cidrs, [var.vpc_cidr_block]) :
    "http-${idx}" => {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP from ${cidr}"
      cidr_ipv4   = cidr
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr_block
    }
  }

  # Listener 설정
  # 현재는 ACM 인증서가 없어 HTTP(80)만 사용
  # 보안 참고: ACM 인증서 생성 후 HTTP(80) -> HTTPS(443) 리다이렉트 구성 필요
  #           보안상 HTTPS(443)만 허용하고 HTTP 요청은 HTTPS로 리다이렉트하는 것이 권장됨
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "instances"
      }
    }
  }

  # Target Group 설정
  target_groups = {
    instances = {
      name_prefix          = substr(var.name, 0, 5)
      protocol             = "HTTP"
      port                 = try(var.config.target_port, 80)
      target_type          = "instance"
      deregistration_delay = 10
      create_attachment    = false  # additional_target_group_attachments 사용하므로 자동 생성 비활성화

      health_check = {
        enabled             = true
        interval            = try(var.config.health_check.interval, 30)
        path                = try(var.config.health_check.path, "/health")
        port                = "traffic-port"
        healthy_threshold   = try(var.config.health_check.healthy_threshold, 2)
        unhealthy_threshold = try(var.config.health_check.unhealthy_threshold, 2)
        timeout             = try(var.config.health_check.timeout, 5)
        protocol            = "HTTP"
        matcher             = try(var.config.health_check.matcher, "200")
      }

      protocol_version = "HTTP1"
    }
  }

  # EC2 인스턴스를 Target Group에 연결
  additional_target_group_attachments = {
    for idx, instance_id in var.target_instances :
    "instance-${idx}" => {
      target_group_key = "instances"
      target_type      = "instance"
      target_id        = instance_id
      port             = try(var.config.target_port, 80)
    }
  }

  tags = local.tags
}
