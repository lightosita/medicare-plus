variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "kms_s3_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  type        = string
}

variable "imaging_lifecycle_days" {
  description = "Days before imaging files move to S3 Glacier for cost optimisation"
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "Days before access logs are permanently deleted"
  type        = number
  default     = 365
}

variable "enable_replication" {
  description = "Whether to enable cross-region replication for imaging bucket"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Destination region for cross-region replication"
  type        = string
  default     = "us-west-2"
}