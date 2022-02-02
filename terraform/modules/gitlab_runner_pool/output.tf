output "runner_security_group_id" {
  value = aws_security_group.gitlab_runner.id
}

output "runner_asg_id" {
  value = aws_autoscaling_group.gitlab_runner.id
}

output "runner_asg_name" {
  value = aws_autoscaling_group.gitlab_runner.name
}