variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where KMS keys will be created"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Number of days before KMS key is deleted after destruction"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Whether to enable automatic annual key rotation"
  type        = bool
  default     = true
}