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
  execution_role_arn       = var.execution_role_arn
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
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.react_app_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "react-app"
        }
      }
    }
  ])
}

# CloudWatchロググループ
resource "aws_cloudwatch_log_group" "react_app_logs" {
  name              = "my-react-app-logs"
  retention_in_days = 7
  tags = {
    Name = "my-react-app-logs"
  }
}

# ECSサービス
resource "aws_ecs_service" "react_app" {
  name            = "my-react-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.react_app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets          = [var.public_subnet_1_id, var.public_subnet_2_id]
    security_groups  = [var.security_group_for_fargate_id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = var.aws_lb_target_group_react_app_arn
    container_name   = "react-app"
    container_port   = 3000
  }
  depends_on = [var.aws_lb_listener_http]
}

