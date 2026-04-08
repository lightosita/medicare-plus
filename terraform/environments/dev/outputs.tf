output "alb_dns_name" {
  description = "ALB DNS name — point your domain here"
  value       = module.compute.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.database.rds_instance_id
}

output "imaging_bucket" {
  description = "Medical imaging S3 bucket name"
  value       = module.storage.imaging_bucket_id
}

output "documents_bucket" {
  description = "Patient documents S3 bucket name"
  value       = module.storage.documents_bucket_id
}

output "audit_logs_bucket" {
  description = "Compliance audit logs bucket name"
  value       = module.storage.audit_logs_bucket_id
}

output "emergency_topic_arn" {
  description = "Emergency SNS topic ARN"
  value       = module.notifications.emergency_topic_arn
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.database.db_endpoint
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.database.redis_endpoint
}