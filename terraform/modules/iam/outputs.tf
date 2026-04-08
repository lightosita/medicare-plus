output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role — used by ECS to pull images and secrets"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role — used by the running application container"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task.name
}

output "lambda_emergency_role_arn" {
  description = "ARN of the Lambda emergency notification role"
  value       = aws_iam_role.lambda_emergency.arn
}

output "lambda_emergency_role_name" {
  description = "Name of the Lambda emergency notification role"
  value       = aws_iam_role.lambda_emergency.name
}