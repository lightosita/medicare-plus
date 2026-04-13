# modules/secrets/variables.tf

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
}

variable "project_name" {
  type        = string
  description = "Project name used as a resource prefix"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt secrets"
}

variable "db_username" {
  type        = string
  description = "PostgreSQL master username"
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
}

# Endpoints are passed in from the database module output.
# They can be empty strings on first apply - the lifecycle
# ignore_changes on the secret version handles this gracefully.
variable "rds_endpoint" {
  type        = string
  description = "RDS instance endpoint (host only, no port)"
  default     = ""
}

variable "redis_endpoint" {
  type        = string
  description = "ElastiCache Redis primary endpoint"
  default     = ""
}

variable "recovery_window_in_days" {
  type        = number
  description = "Days before a deleted secret is permanently removed"
  default     = 30
}

# VPC variables required by the rotation Lambda
variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the rotation Lambda VPC config"
}

variable "lambda_security_group_id" {
  type        = string
  description = "Security group ID that allows the rotation Lambda to reach RDS"
}