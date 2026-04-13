# modules/secrets/outputs.tf

output "db_credentials_secret_arn" {
  description = "ARN of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "redis_credentials_secret_arn" {
  description = "ARN of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}

output "app_config_secret_arn" {
  description = "ARN of the application config secret"
  value       = aws_secretsmanager_secret.app_config.arn
}

# Expose generated passwords as sensitive outputs so the
# database module can receive the password it needs to
# create the RDS instance on first apply.
output "db_password" {
  description = "Generated RDS master password"
  value       = random_password.db.result
  sensitive   = true
}

output "redis_auth_token" {
  description = "Generated Redis AUTH token"
  value       = random_password.redis.result
  sensitive   = true
}