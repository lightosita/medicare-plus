# MediCare+ Healthcare Management System

## Project Overview

Production-grade cloud infrastructure for a healthcare management system (MediCare+) on AWS, built with Terraform and deployed via a GitHub Actions CI/CD pipeline to Terraform Cloud.

This project is part of a cloud architecture scenario-based assignment demonstrating real-world decision-making for healthcare systems.

---

## What This Project Demonstrates

- Production-grade AWS infrastructure design using Terraform modules
- Secure healthcare system design (HIPAA-aware patterns)
- Defence-in-depth security (KMS, Secrets Manager, IAM least privilege, network isolation)
- Event-driven architecture (SNS, SQS, Lambda)
- Scalable containerised workloads (ECS Fargate with auto-scaling)
- CI/CD pipeline (GitHub Actions → Terraform Cloud)
- Real-world trade-off analysis (modular monolith vs microservices)

---

## Architecture Approach

| Decision | Choice | Reason |
|---|---|---|
| Application pattern | Modular monolith + one extracted microservice | 8-engineer team, quarterly deployments, tightly coupled medical domain |
| Compute | ECS Fargate | No server management, scales to zero, pay-per-task |
| Primary database | RDS PostgreSQL | ACID compliance for clinical data — prescriptions, appointments, records |
| Cache | ElastiCache Redis | Sub-millisecond reads for session tokens and appointment availability |
| Storage | S3 (3 buckets) | Medical imaging, patient documents, and compliance audit logs |
| Secrets | AWS Secrets Manager | Auto-rotating credentials — no hardcoded secrets anywhere |
| Encryption | AWS KMS (3 keys) | Separate keys for main, RDS, and S3 to limit blast radius |

---

## Security Architecture (Defence in Depth)

### Layer 1 — Network Isolation
- VPC with three subnet tiers: public, private, and isolated
- ALB is the **only** internet-facing resource
- ECS tasks run in **private subnets** — no public IPs
- RDS and Redis run in **isolated subnets** — no route to internet at all
- Security groups enforce least-privilege port access (443, 5432, 6379)
- VPC Flow Logs capture all accepted and rejected traffic

### Layer 2 — Encryption
- RDS encrypted at rest via KMS (dedicated RDS key)
- S3 buckets encrypted via KMS (dedicated S3 key)
- ElastiCache TLS in-transit + KMS at-rest
- TLS 1.2+ enforced at ALB via ACM-managed certificate
- All data in motion encrypted end-to-end

### Layer 3 — Identity & Access
- IAM roles with least-privilege policies per workload (ECS task, ECS execution, Lambda emergency, secrets rotation)
- No hardcoded AWS credentials anywhere in the codebase
- Secrets Manager stores all database passwords and API keys
- Automatic secret rotation every 30 days via Lambda

### Layer 4 — Observability & Alerting
- CloudWatch alarms on RDS CPU, RDS storage, Redis CPU, and Lambda errors
- CloudWatch log groups for ECS, Lambda, and VPC flow logs
- DynamoDB audit table for emergency alert delivery records

> **Note on dev vs prod:** The dev environment uses lighter settings (single NAT gateway, single-AZ RDS, 7-day backups) to reduce cost. The prod environment enables Multi-AZ RDS, 35-day backups, and cross-region S3 replication. Services planned for production include AWS WAF, Amazon Cognito, CloudTrail, and AWS Config.

---

## Infrastructure Modules

| Module | Resources |
|---|---|
| `networking` | VPC, subnets (public/private/isolated), IGW, NAT GW, route tables, security groups, VPC flow logs |
| `compute` | ECS Fargate cluster, task definition, service, ALB, target group, auto-scaling (CPU + memory) |
| `database` | RDS PostgreSQL, ElastiCache Redis, parameter groups, subnet groups, CloudWatch alarms |
| `secrets` | Secrets Manager (db, redis, app-config), rotation Lambda, IAM rotation role |
| `kms` | 3 KMS keys (main, rds, s3) with aliases and key rotation enabled |
| `iam` | ECS task role, ECS execution role, Lambda emergency role — all with least-privilege policies |
| `storage` | S3 buckets (imaging, documents, audit-logs) with versioning, lifecycle, SSE-KMS, object lock |
| `notifications` | SNS topics (emergency, appointments, lab-results), SQS queues (billing, hospital, audit-FIFO) with DLQs, DynamoDB alerts table, emergency Lambda |

---

## Environments

| Environment | Backend | State |
|---|---|---|
| `dev` | Terraform Cloud (`teleios-light-dev`) | Active — all modules deployed |
| `prod` | S3 (`prod/terraform.tfstate`) | Active — full HA config (Multi-AZ, 35-day backups, cross-region S3 replication) |

> Staging environment was removed — dev and prod environments are sufficient for this project scope.

---

## CI/CD Pipeline

Every push to `main` triggers the pipeline:

```
git push → GitHub Actions → terraform init → terraform validate → terraform plan → terraform apply → Terraform Cloud (teleios-light-dev)
```

Secrets stored in GitHub Actions:
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `TF_API_TOKEN`
- `TF_VAR_DB_USERNAME`

---

## How to Deploy

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.6.0
- Terraform Cloud account with `Teleios` organisation access

### Deploy dev environment

```bash
cd terraform/environments/dev
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

---

## Scenario Context

| Parameter | Value |
|---|---|
| Team size | 8 engineers |
| Users | 20,000 patients · 500 doctors · 50 administrators |
| Uptime requirement | 99.5% |
| Deployment cycle | Quarterly |
| Compliance | HIPAA-aware patterns |

---

## Repository Structure

```
medicare-plus/
├── README.md
├── analysis/
│   └── healthcare.md
├── .github/
│   └── workflows/
│       └── terraform.yml
└── terraform/
    ├── backend.tf
    ├── environments/
    │   ├── dev/
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   ├── outputs.tf
    │   │   └── terraform.tfvars
    │   └── prod/
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    └── modules/
        ├── compute/
        ├── database/
        ├── iam/
        ├── kms/
        ├── networking/
        ├── notifications/
        ├── secrets/
        └── storage/
```

---

## Tech Stack

| Category | Technology |
|---|---|
| Cloud | AWS (us-east-1) |
| IaC | Terraform >= 1.6.0 |
| CI/CD | GitHub Actions + Terraform Cloud |
| Container runtime | ECS Fargate |
| Primary database | Amazon RDS PostgreSQL |
| Cache | Amazon ElastiCache Redis |
| Object storage | Amazon S3 |
| Secrets | AWS Secrets Manager |
| Encryption | AWS KMS |
| Notifications | Amazon SNS + SQS |
| Serverless | AWS Lambda |
| Monitoring | Amazon CloudWatch |
