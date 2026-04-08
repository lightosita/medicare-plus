variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used for ARN construction"
  type        = string
}

variable "kms_main_key_arn" {
  description = "ARN of the main KMS key for Secrets Manager access"
  type        = string
}

variable "kms_rds_key_arn" {
  description = "ARN of the RDS KMS key"
  type        = string
}

variable "kms_s3_key_arn" {
  description = "ARN of the S3 KMS key"
  type        = string
}