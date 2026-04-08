output "main_key_arn" {
  description = "ARN of the main KMS key used for Secrets Manager"
  value       = aws_kms_key.main.arn
}

output "main_key_id" {
  description = "ID of the main KMS key"
  value       = aws_kms_key.main.key_id
}

output "s3_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "s3_key_id" {
  description = "ID of the S3 KMS key"
  value       = aws_kms_key.s3.key_id
}

output "rds_key_arn" {
  description = "ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "rds_key_id" {
  description = "ID of the RDS KMS key"
  value       = aws_kms_key.rds.key_id
}