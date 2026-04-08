variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where secrets will be created"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt secrets"
  type        = string
}

variable "db_username" {
  description = "Master username for RDS PostgreSQL — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS PostgreSQL — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
}

variable "redis_password" {
  description = "Auth token for ElastiCache Redis — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "recovery_window_in_days" {
  description = "Days before a deleted secret is permanently removed"
  type        = number
  default     = 30
}