output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "route53_record" {
  value = aws_route53_record.www.fqdn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.react_app.repository_url
}