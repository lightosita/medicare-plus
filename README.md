# MediCare+ Healthcare Management System

## Project Overview
Production-grade cloud architecture and infrastructure implementation for a healthcare management system(MediCare+) on AWS.

This project is part of a cloud architecture scenario-based assignment demonstrating real-world decision-making for healthcare systems.


## What This Project Demonstrates

- Production-grade AWS infrastructure design
- Terraform modular architecture (reusable modules)
- Secure healthcare system design (HIPAA-aware patterns)
- Event-driven architecture (SNS, SQS, Lambda)
- Scalable containerized workloads (ECS Fargate)
- Real-world trade-off analysis (monolith vs microservices)

## How to Deploy

### Prerequisites
- AWS CLI configured
- Terraform >= 1.6

### Steps

cd terraform/environments/dev
terraform init
terraform plan
terraform apply

## Scenario Context
- **Team Size:** 8 engineers (small, experienced)
- **Users:** 20,000 patients, 500 doctors, 50 administrators
- **Uptime Requirement:** 99.5%
- **Deployment Cycle:** Quarterly (cautious)

## Architecture Approach
- **Pattern:** Modular Monolith + one extracted microservice (emergency notifications)
- **Compute:** AWS ECS Fargate
- **Database:** RDS PostgreSQL Multi-AZ + ElastiCache Redis
- **Storage:** S3 with intelligent tiering
- **Security:** Defence in depth — WAF, KMS encryption, Secrets Manager, Cognito MFA


## Security Highlights

- Secrets managed via AWS Secrets Manager
- No hardcoded credentials
- IAM roles with least privilege
- Private subnets for all compute and databases
- Encryption at rest (KMS) and in transit (TLS)


## Architecture Diagram

See `/diagrams` for system design visuals.


## Repository Structure

medicare-plus/
├── README.md
├── analysis/
│   └── scenario3-healthcare.md
├── diagrams/
├── terraform/
│   ├── README.md
│   ├── backend.tf
│   ├── environments/
│   │   ├── dev/
│   │   ├── prod/
│   │   └── staging/
│   └── modules/
│       ├── compute/
│       ├── database/
│       ├── iam/
│       ├── kms/
│       ├── networking/
│       ├── notifications/
│       ├── secrets/
│       └── storage/



## Tech Stack
- **Cloud:** AWS
- **IaC:** Terraform >= 1.6
- **Container:** ECS Fargate
- **Database:** Amazon RDS (PostgreSQL), Amazon ElastiCache (Redis)
- **Auth:** Amazon Cognito
- **Notifications:** SNS + Lambda