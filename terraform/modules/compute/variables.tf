variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where compute resources are deployed"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for ECS tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task runtime role"
  type        = string
}

variable "db_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  type        = string
}

variable "redis_credentials_secret_arn" {
  description = "ARN of the Redis credentials secret"
  type        = string
}

variable "app_config_secret_arn" {
  description = "ARN of the application config secret"
  type        = string
}

variable "app_image" {
  description = "Docker image URI for the main application"
  type        = string
}

variable "app_cpu" {
  description = "CPU units for the ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "app_memory" {
  description = "Memory in MB for the ECS task"
  type        = number
  default     = 2048
}

variable "app_desired_count" {
  description = "Desired number of ECS task instances"
  type        = number
  default     = 2
}

variable "app_min_count" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 1
}

variable "app_max_count" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 10
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS PostgreSQL endpoint passed to application"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "ElastiCache Redis endpoint passed to application"
  type        = string
  sensitive   = true
}