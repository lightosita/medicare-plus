variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where database resources are deployed"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where databases will be deployed"
  type        = string
}

variable "isolated_subnet_ids" {
  description = "IDs of isolated subnets for RDS and ElastiCache"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS PostgreSQL"
  type        = string
}

variable "redis_security_group_id" {
  description = "Security group ID for ElastiCache Redis"
  type        = string
}

variable "kms_rds_key_arn" {
  description = "ARN of the KMS key for RDS encryption"
  type        = string
}

variable "db_username" {
  description = "Master username for RDS — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class — varies per environment"
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache node type — varies per environment"
  type        = string
}

variable "redis_password" {
  description = "Auth token for ElastiCache Redis — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Days to retain RDS automated backups"
  type        = number
  default     = 35
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ for RDS — always true in prod"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental RDS deletion — always true in prod"
  type        = bool
  default     = true
}