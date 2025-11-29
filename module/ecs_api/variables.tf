variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "ecr_repository_name" {
  type        = string
}

variable "ecr_image_version" {
  type        = string
}

variable "public_subnet_1_id" {
  type        = string
}

variable "public_subnet_2_id" {
  type        = string
}

variable "security_group_for_fargate_id" {
  type        = string
}

variable "aws_lb_listener_http" {
  type        = any
}

variable "aws_lb_target_group_go_app_arn" {
  type        = string
}

variable "execution_role_arn" {
  type        = string
}

variable "db_host" {
  type        = string
}

variable "db_user" {
  type        = string
}

variable "db_password" {
  type        = string
}

variable "db_name" {
  type        = string
}

variable "db_sslmode" {
  type        = string
}

variable "auth0_domain" {
  type        = string
}

variable "auth0_audience" {
  type        = string
}