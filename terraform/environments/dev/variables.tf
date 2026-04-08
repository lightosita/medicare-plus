variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "medicare-plus"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs — for ALB"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs — for ECS tasks"
  type        = list(string)
}

variable "isolated_subnet_cidrs" {
  description = "Isolated subnet CIDRs — for RDS and Redis"
  type        = list(string)
}

variable "db_username" {
  description = "RDS master username — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "medicareplus"
}

variable "redis_password" {
  description = "Redis auth token — injected from Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "app_image" {
  description = "Docker image URI for the application"
  type        = string
}

variable "app_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "ECS task memory in MB"
  type        = number
  default     = 512
}

variable "app_desired_count" {
  description = "Desired ECS task count"
  type        = number
  default     = 1
}

variable "app_min_count" {
  description = "Minimum ECS task count"
  type        = number
  default     = 1
}

variable "app_max_count" {
  description = "Maximum ECS task count"
  type        = number
  default     = 3
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}