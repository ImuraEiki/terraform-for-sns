# 新規ECRリポジトリ作成
# resource "aws_ecr_repository" "go_app" {
#   name = var.ecr_repository_name
#   tags = {
#     Name = "my-go-app-ecr"
#   }
# }

# 既存ECRリポジトリから取得
data "aws_ecr_repository" "go_app" {
  name = var.ecr_repository_name  
}

# ECSクラスタ
resource "aws_ecs_cluster" "main" {
  name = "my-cluster"
}

# ECSタスク定義（Goアプリ）
resource "aws_ecs_task_definition" "go_app" {
  family                   = "my-go-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  container_definitions = jsonencode([
    {
      name      = "go-app"
      image     = "${data.aws_ecr_repository.go_app.repository_url}:${var.ecr_image_version}"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.go_app_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "go-app"
        }
      }
      environment = [
        { name = "DB_HOST",     value = var.db_host },
        { name = "DB_USER",     value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "DB_NAME",     value = var.db_name },
        { name = "DB_PORT",     value = "5432" },
        { name = "DB_SSLMODE",  value = var.db_sslmode},
        { name = "AUTH0_DOMAIN", value = var.auth0_domain},
        { name = "AUTH0_AUDIENCE", value = var.auth0_audience}
      ]
    }
  ])
}

# CloudWatchロググループ
resource "aws_cloudwatch_log_group" "go_app_logs" {
  name              = "my-go-app-logs"
  retention_in_days = 7
  tags = {
    Name = "my-go-app-logs"
  }
}

# ECSサービス
resource "aws_ecs_service" "go_app" {
  name            = "my-go-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.go_app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets          = [var.public_subnet_1_id, var.public_subnet_2_id]
    security_groups  = [var.security_group_for_fargate_id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = var.aws_lb_target_group_go_app_arn
    container_name   = "go-app"
    container_port   = 8080
  }
  depends_on = [var.aws_lb_listener_http]
}