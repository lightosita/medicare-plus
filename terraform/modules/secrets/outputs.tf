output "db_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "redis_credentials_secret_arn" {
  description = "ARN of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}

output "redis_credentials_secret_name" {
  description = "Name of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.name
}

output "app_config_secret_arn" {
  description = "ARN of the application config secret"
  value       = aws_secretsmanager_secret.app_config.arn
}

output "app_config_secret_name" {
  description = "Name of the application config secret"
  value       = aws_secretsmanager_secret.app_config.name
}