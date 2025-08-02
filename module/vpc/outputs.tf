output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "The ID of the first public subnet"
  value       = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "The ID of the second public subnet"
  value       = aws_subnet.public_2.id
}

output "security_group_for_alb_id" {
  description = "The security group ID for the ALB"
  value       = aws_security_group.alb_sg.id
}

output "security_group_for_fargate_id" {
  description = "The security group ID for Fargate tasks"
  value       = aws_security_group.fargate_sg.id
}
