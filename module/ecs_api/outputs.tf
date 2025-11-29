output "ecr_repository_url" {
  value = data.aws_ecr_repository.go_app.repository_url
}