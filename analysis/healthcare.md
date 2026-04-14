# Healthcare Management System — MediCare+

## 1. Architecture Recommendation

### Decision: Modular Monolith with One Extracted Microservice

After analysing the constraints of MediCare+, a modular monolith is recommended over a full microservices approach. The following factors drive this decision:

**Team Size (8 engineers)**
Microservices require dedicated ownership per service — typically 3–5 engineers minimum per service. With 8 engineers managing 6+ independent services, most capacity would be consumed by coordination overhead rather than feature development. A modular monolith maintains clear internal boundaries without the operational burden of distributed systems.

**Quarterly Deployment Cycle**
The primary benefit of microservices is independent deployability. With quarterly deployments, this benefit is largely wasted. A monolith deployed every quarter carries significantly less operational risk than coordinating multi-service releases across a small team.

**Tight Domain Coupling**
Medical records, appointments, prescriptions, and lab results are deeply coupled. A doctor viewing a patient record needs simultaneous access to all four. Splitting these into separate services creates distributed joins — complex, slow, and dangerous in a clinical context where incomplete data can affect clinical decisions.

**The One Exception: Emergency Notifications**
The emergency notification system is extracted as a standalone AWS Lambda function because it has fundamentally different characteristics:
- Must scale from zero to thousands of invocations instantly
- Has no persistent state
- Has no coupling to the core domain logic
- Its failure must never affect the main application

### Internal Module Boundaries
Although deployed as a single unit, the codebase is organised into clearly separated modules:
- Patient Records Module
- Appointment Scheduling Module
- Prescription Management Module
- Lab Results & Imaging Module
- Billing & Insurance Module
- Telemedicine Module

Each module owns its data access layer and exposes internal interfaces. This structure allows future extraction into microservices if the team grows or deployment frequency increases.

---

## 2. Communication Design

### Synchronous Interactions (Immediate Response Required)

| Interaction      | Pattern       | Justification |
|---                |---            |---        |
| Appointment booking | REST | Double-booking prevention requires a database lock and immediate confirmation |
| Prescription dispensing | REST | Drug interaction check must complete before prescription is issued |
| Telemedicine session start | WebSocket | Live video requires real-time bidirectional connection |
| Patient authentication | REST | Access control decisions cannot be deferred |
| Lab result retrieval | REST | Doctor expects immediate response when viewing results |

### Asynchronous Interactions (Eventual Consistency Acceptable)

| Interaction | Tool | Justification |
|---|---|---|
| Billing & insurance claims | SQS | Claims processed by insurers over hours or days |
| Appointment reminders | SNS | SMS/email delivery, no response needed |
| Lab result notifications | SNS | Patient notified when results are ready |
| Audit log writes | SQS FIFO | Logs must be ordered but need not block the request |
| Hospital system sync | SQS + Lambda | External systems have their own SLAs |

### Emergency Notification System (Deployed)
The emergency notification system uses an isolated Lambda function with its own SNS topics and DynamoDB table:

1. Emergency trigger fires (critical lab result, patient alert)
2. Lambda function invoked directly
3. SNS topic fans out to emergency, appointments, and lab-results topics
4. SQS queues (billing, hospital-integration, audit-FIFO) decouple downstream consumers
5. Dead letter queues capture failed messages for manual review
6. All alerts logged to DynamoDB alerts table with immutable timestamp

---

## 3. Data Architecture

### Database Selection

**Amazon RDS PostgreSQL — deployed**
Used for: patient records, appointments, prescriptions, billing, user accounts

Justification: ACID compliance is non-negotiable in a clinical context. A prescription cannot exist without a patient and a doctor. An appointment cannot exist without an available slot. Multi-AZ deployment in production provides automatic failover (60–120 seconds) sufficient to meet the 99.5% uptime requirement.

Dev configuration: `db.t3.micro`, single-AZ, 7-day backups, deletion protection off
Prod configuration: `db.t3.medium`, Multi-AZ, 35-day backups, deletion protection on

**Amazon ElastiCache Redis — deployed**
Used for: session state, telemedicine session tokens, appointment slot availability cache

Justification: Reading doctor availability from PostgreSQL on every scheduling request creates unnecessary load. Redis provides sub-millisecond reads for frequently accessed, short-lived data. Session tokens for telemedicine are stored with a TTL matching session duration.

Dev configuration: `cache.t3.micro`, replication group, TLS in-transit, KMS at-rest
Prod configuration: `cache.t3.medium`

**Amazon S3 — deployed (3 buckets)**
Used for: medical imaging (X-rays, MRI, ultrasounds), patient documents, compliance audit logs

Justification: Medical images range from 50MB–500MB. Storing binary objects in a relational database is an antipattern. S3 provides 99.999999999% durability. Lifecycle policies automatically move imaging data to cheaper storage tiers after 30 days (dev) or 90 days (prod). Images are accessed via pre-signed URLs — never exposed publicly.

All buckets: versioning enabled, SSE-KMS encryption, public access blocked, lifecycle rules
Audit logs bucket: object lock enabled for compliance immutability

**Amazon DynamoDB — deployed**
Used for: emergency alert delivery records, notification history

Justification: Audit logs are write-heavy, append-only, and never updated. They are queried by alert ID or timestamp — a perfect fit for DynamoDB's key-value model. Healthcare compliance requires immutable audit trails.

### Data Classification

| Tier | Data Types | Controls Implemented |
|---|---|---|
| High sensitivity | Diagnoses, prescriptions, lab results | KMS encryption (dedicated RDS key), Secrets Manager for credentials |
| Medium sensitivity | Appointment metadata, billing records | KMS at-rest, private subnet isolation |
| Low sensitivity | Audit metadata, notification logs | DynamoDB, separate from clinical data |

### Backup & Recovery (Prod)

- RDS automated backups: 35-day retention, point-in-time recovery
- RDS snapshots: daily automated + manual before quarterly deployments
- S3 versioning: enabled on all three buckets
- S3 cross-region replication: enabled for imaging bucket (prod only)
- Recovery Time Objective (RTO): 2 hours
- Recovery Point Objective (RPO): 1 hour

---

## 4. Security Architecture (Defence in Depth)

### Layer 1 — Network Isolation
- Three subnet tiers: public, private, isolated
- ALB is the **only** internet-facing resource — all other resources have no public IPs
- ECS tasks in private subnets, RDS and Redis in isolated subnets (no internet route)
- Security groups enforce least-privilege: ALB→ECS port 443, ECS→RDS port 5432, ECS→Redis port 6379
- VPC Flow Logs capture all accepted and rejected connections → CloudWatch

### Layer 2 — Encryption at Rest and in Transit
- RDS: AES-256 via dedicated KMS key (`medicare-plus-dev-rds`)
- S3: SSE-KMS via dedicated S3 key (`medicare-plus-dev-s3`) on all three buckets
- ElastiCache: TLS in-transit + KMS at-rest
- ALB: TLS 1.2+ via ACM-managed certificate (`babest.online`)
- Secrets Manager: all credentials KMS-encrypted with main key

### Layer 3 — Identity & Access
- IAM roles with least-privilege policies per workload:
  - `medicare-plus-dev-ecs-execution-role` — pull images, write logs
  - `medicare-plus-dev-ecs-task-role` — access secrets, S3, KMS
  - `medicare-plus-dev-lambda-emergency-role` — SNS publish, DynamoDB write
  - `medicare-plus-dev-secret-rotation-role` — rotate Secrets Manager credentials
- No hardcoded credentials anywhere — all via Secrets Manager
- Automatic secret rotation every 30 days via Lambda

### Layer 4 — Observability & Alerting
- CloudWatch alarms: RDS CPU > threshold, RDS storage low, Redis CPU > threshold, Lambda errors
- CloudWatch log groups: ECS application, Lambda emergency, Lambda rotation, VPC flow logs
- DynamoDB audit table: immutable emergency alert records

### Planned for Production
- AWS WAF on ALB (SQLi, XSS, credential-stuffing rules)
- Amazon Cognito (patient and staff authentication, MFA for doctors and admins)
- AWS CloudTrail (full API audit trail, 7-year retention)
- AWS Config (continuous compliance evaluation, security group open-to-internet alerts)

---

## 5. Cloud Resource Planning

### Compute

**AWS ECS Fargate — deployed**
Chosen over EKS and EC2:
- EKS requires Kubernetes expertise for control plane upgrades, node groups, and CNI plugins — consuming 2–3 of the available DevOps engineers entirely
- EC2 requires OS patching, AMI management, and capacity planning
- Fargate removes all server management — define a container and CPU/memory spec, AWS handles the rest
- For quarterly deployments, operational simplicity outweighs any performance advantage of Kubernetes

Dev task sizing: 256 CPU units, 512 MB RAM, scales 1→3 tasks (CPU + memory policies)
Prod task sizing: 1 vCPU, 2 GB RAM, scales 2→10 tasks

**AWS Lambda — deployed**
Used for emergency notification dispatch and automatic secrets rotation. Event-driven, stateless, scales to zero when not in use.

### Networking (deployed)

- VPC: `10.1.0.0/16` (dev), `10.0.0.0/16` (prod)
- Public subnets (2 AZs): ALB only
- Private subnets (2 AZs): ECS tasks, Lambda functions
- Isolated subnets (2 AZs): RDS, ElastiCache
- Single NAT Gateway in dev (cost saving), one per AZ in prod (HA)
- VPC Flow Logs → CloudWatch

---

## 6. Trade-off Analysis

### Trade-off 1: Modular Monolith vs Microservices
**Decision:** Modular monolith

**What we gain:** Deployment simplicity, transactional data consistency, reduced operational overhead, faster development for a small team.

**What we give up:** Independent scaling of individual features, fault isolation between domains.

**Mitigation:** Module boundaries are enforced in code. If the team grows beyond 15 engineers or deployment frequency increases to weekly, individual modules can be extracted without a full rewrite.

### Trade-off 2: ECS Fargate vs EKS
**Decision:** ECS Fargate

**What we gain:** Zero server management, no Kubernetes expertise required, pay-per-second billing, simpler IAM integration.

**What we give up:** Advanced scheduling, service mesh capabilities, multi-cloud portability.

**Mitigation:** Fargate is fully sufficient for a modular monolith with predictable traffic patterns. EKS would add significant operational overhead for a team of 8.

### Trade-off 3: RDS Multi-AZ vs Aurora PostgreSQL
**Decision:** RDS Multi-AZ (prod)

**What we gain:** ~3× lower cost than Aurora, simpler operational model, sufficient performance for 20,000 patients.

**What we give up:** Aurora's faster failover (< 30 seconds vs 60–120 seconds), Aurora Serverless auto-scaling.

**Mitigation:** Architecture is designed to allow migration to Aurora Serverless v2 if patient load grows beyond 100,000 users or if the failover window proves insufficient.

### Trade-off 4: Single Region Multi-AZ vs Multi-Region
**Decision:** Single region, Multi-AZ

**What we gain:** Lower operational complexity, lower cost, simpler data residency compliance.

**What we give up:** Protection against a full AWS regional outage.

**Mitigation:** Multi-AZ handles hardware and AZ-level failures, which are far more common than regional failures. The 99.5% uptime requirement (~44 hours downtime per year) does not require multi-region redundancy. S3 cross-region replication protects imaging data independently of compute.

### Trade-off 5: KMS Customer-Managed Keys vs AWS-Managed Keys
**Decision:** Customer-managed KMS keys (3 separate keys)

**What we gain:** Full control over key policy, ability to disable/rotate independently, blast-radius reduction (compromised S3 key does not expose RDS data).

**What we give up:** Small additional cost per key, slightly more complex key policy management.

**Mitigation:** Three keys (main, rds, s3) provide meaningful isolation without the complexity of per-resource keys.

### Trade-off 6: Secrets Manager vs SSM Parameter Store
**Decision:** AWS Secrets Manager

**What we gain:** Built-in automatic rotation, purpose-built for credentials, audit trail per secret access.

**What we give up:** Higher cost (~$0.40/secret/month vs free tier for SSM).

**Mitigation:** For a healthcare system where credential exposure could mean HIPAA breach, the cost of Secrets Manager is justified. Automatic rotation means credentials are never stale — a critical control for clinical data.
