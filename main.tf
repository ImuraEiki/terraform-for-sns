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

# 新規ECRリポジトリ作成
# resource "aws_ecr_repository" "react_app" {
#   name = var.ecr_repository_name
#   tags = {
#     Name = "my-react-app-ecr"
#   }
# }

# 既存ECRリポジトリから取得
data "aws_ecr_repository" "react_app" {
  name = var.ecr_repository_name  
}

# ECSクラスタ
resource "aws_ecs_cluster" "main" {
  name = "my-cluster"
}

# ECSタスク定義（Reactアプリ）
resource "aws_ecs_task_definition" "react_app" {
  family                   = "my-react-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "react-app"
      image     = "${data.aws_ecr_repository.react_app.repository_url}:${var.ecr_image_version}"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

# ECSサービス
resource "aws_ecs_service" "react_app" {
  name            = "my-react-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.react_app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets          = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
    security_groups  = [module.vpc.security_group_for_fargate_id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.react_app.arn
    container_name   = "react-app"
    container_port   = 3000
  }
  depends_on = [aws_lb_listener.http]
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