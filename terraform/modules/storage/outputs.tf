output "imaging_bucket_id" {
  description = "ID of the medical imaging S3 bucket"
  value       = aws_s3_bucket.imaging.id
}

output "imaging_bucket_arn" {
  description = "ARN of the medical imaging S3 bucket"
  value       = aws_s3_bucket.imaging.arn
}

output "documents_bucket_id" {
  description = "ID of the patient documents S3 bucket"
  value       = aws_s3_bucket.documents.id
}

output "documents_bucket_arn" {
  description = "ARN of the patient documents S3 bucket"
  value       = aws_s3_bucket.documents.arn
}

output "audit_logs_bucket_id" {
  description = "ID of the compliance audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the compliance audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.arn
}