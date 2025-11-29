variable "region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  default = "10.0.2.0/24"
}

variable "domain_name" {
  default = "eiki-imura-app.com"
}

variable "ecr_repository_name" {
  default = "my-react-app"
}

variable "ecr_go_repository_name" {
  default = "my-go-app"
}

variable "ecr_image_version" {
  default = "515cf8c"
}

variable "ecr_go_image_version" {
  default = "4186d43"
}

variable "db_host" {
  default = ""
  sensitive = true
}

variable "db_user" {
  default = "eiki"
}

variable "db_password" {
  default = ""
  sensitive = true
}

variable "db_name" {
  default = "portfolio"
}

variable "db_sslmode" {
  default = "prefer"
}

variable "auth0_domain" {
  default = ""
  sensitive = true
}

variable "auth0_audience" {
  default = ""
  sensitive = true
}