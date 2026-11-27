output "alb_dns_name" {
  description = "Adresse publique de l'ALB"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN du target group"
  value       = aws_lb_target_group.web.arn
}

output "asg_name" {
  description = "Nom du groupe d'auto-scaling"
  value       = aws_autoscaling_group.web.name
}
