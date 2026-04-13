output "emergency_topic_arn" {
  description = "ARN of the emergency SNS topic"
  value       = aws_sns_topic.emergency.arn
}

output "appointments_topic_arn" {
  description = "ARN of the appointments SNS topic"
  value       = aws_sns_topic.appointments.arn
}

output "lab_results_topic_arn" {
  description = "ARN of the lab results SNS topic"
  value       = aws_sns_topic.lab_results.arn
}

output "billing_queue_url" {
  description = "URL of the billing SQS queue"
  value       = aws_sqs_queue.billing.url
}

output "billing_queue_arn" {
  description = "ARN of the billing SQS queue"
  value       = aws_sqs_queue.billing.arn
}

output "hospital_integration_queue_url" {
  description = "URL of the hospital integration SQS queue"
  value       = aws_sqs_queue.hospital_integration.url
}

output "audit_fifo_queue_url" {
  description = "URL of the audit FIFO SQS queue"
  value       = aws_sqs_queue.audit_fifo.url
}

output "emergency_lambda_arn" {
  description = "ARN of the emergency notification Lambda function"
  value       = aws_lambda_function.emergency.arn
}

output "alerts_table_name" {
  description = "Name of the DynamoDB alerts table"
  value       = aws_dynamodb_table.alerts.name
}

output "alerts_table_arn" {
  description = "ARN of the DynamoDB alerts table"
  value       = aws_dynamodb_table.alerts.arn
}