terraform {
  required_version = ">= 1.12.2"
  backend "s3" {
  bucket         = "terrafom-state-s3"
  key            = "terraform/terraform.tfstate"
  region         = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC
module "vpc" {
  source                = "./module/vpc"
  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  region                = var.region
}

module "ecs_spa" {
  source = "./module/ecs_spa"
  ecr_repository_name   = var.ecr_repository_name
  region                = var.region
  ecr_image_version     = var.ecr_image_version
  public_subnet_1_id    = module.vpc.public_subnet_1_id
  public_subnet_2_id    = module.vpc.public_subnet_2_id
  security_group_for_fargate_id = module.vpc.security_group_for_fargate_id
  aws_lb_listener_http  = aws_lb_listener.http
  aws_lb_target_group_react_app_arn = aws_lb_target_group.react_app.arn
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
}

module "ecs_api" {
  source = "./module/ecs_api"
  ecr_repository_name   = var.ecr_go_repository_name
  region                = var.region
  ecr_image_version     = var.ecr_go_image_version
  public_subnet_1_id    = module.vpc.public_subnet_1_id
  public_subnet_2_id    = module.vpc.public_subnet_2_id
  security_group_for_fargate_id = module.vpc.security_group_for_fargate_id
  aws_lb_listener_http  = aws_lb_listener.http
  aws_lb_target_group_go_app_arn = aws_lb_target_group.go_app.arn
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  db_host               = var.db_host
  db_user               = var.db_user
  db_password           = var.db_password
  db_name               = var.db_name
  db_sslmode            = var.db_sslmode
  auth0_domain          = var.auth0_domain
  auth0_audience        = var.auth0_audience
}

# IAMロール（ECSタスク実行用）
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRoleForTerraform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ALB
resource "aws_lb" "main" {
  name               = "my-react-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups     = [module.vpc.security_group_for_alb_id]
  subnets            = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
  tags = {
    Name = "my-react-app-alb"
  }
}

# ALBターゲットグループ
resource "aws_lb_target_group" "react_app" {
  name        = "react-app-tg-for-terraform"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/" # Reactアプリのヘルスチェックパス
  }
}

resource "aws_lb_target_group" "go_app" {
  name        = "go-api-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/backend/health" 
  }
}

# ALBリスナー（HTTP）
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.react_app.arn
  }
}

resource "aws_lb_listener_rule" "go_app_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_app.arn
  }

  condition {
    path_pattern {
      values = ["/backend/*"]
    }
  }
}

# Route 53ホストゾーン（既存を想定）
data "aws_route53_zone" "main" {
  name = var.domain_name
}

# Route 53 Aレコード（ALBにエイリアス）
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ACM証明書（HTTPS用）
resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.domain_name}"
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method = "DNS"
}

# Route 53 CNAMEレコード
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = data.aws_route53_zone.main.zone_id
    }
  }
  zone_id = each.value.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# 証明書とRoute 53レコードの関連付け
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ALBリスナー（HTTPS）
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.react_app.arn
  }
}

resource "aws_lb_listener_rule" "https_go_app_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_app.arn
  }

  condition {
    path_pattern {
      values = ["/backend/*"]
    }
  }
}