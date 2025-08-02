provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "my-vpc"
  }
}

# パブリックサブネット（2つのAZで高可用性）
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_1_cidr
  availability_zone = "${var.region}a"
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_2_cidr
  availability_zone = "${var.region}c"
  tags = {
    Name = "public-subnet-2"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "my-igw"
  }
}

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-rt"
  }
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループ（ALB用：HTTP/HTTPS許可）
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-sg"
  }
}

# セキュリティグループ（Fargate用：ALBからのみ許可）
resource "aws_security_group" "fargate_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 3000 # Reactアプリのポート（必要に応じて変更）
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "fargate-sg"
  }
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
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.fargate_sg.id]
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
  security_groups     = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  tags = {
    Name = "my-react-app-alb"
  }
}

# ALBターゲットグループ
resource "aws_lb_target_group" "react_app" {
  name        = "react-app-tg-for-terraform"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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