variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where notification resources are deployed"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for Lambda VPC deployment"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for emergency Lambda function"
  type        = string
}

variable "kms_main_key_arn" {
  description = "ARN of the main KMS key for SNS encryption"
  type        = string
}

variable "db_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  type        = string
}