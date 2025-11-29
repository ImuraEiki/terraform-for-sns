output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "route53_record" {
  value = aws_route53_record.www.fqdn
}
