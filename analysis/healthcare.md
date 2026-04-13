# Scenario 3: Healthcare Management System — MediCare+

## 1. Architecture Recommendation

### Decision: Modular Monolith with One Extracted Microservice

After analysing the constraints of MediCare+, a modular monolith is the 
recommended architecture over a microservices approach. The following factors 
drive this decision:

**Team Size (8 engineers)**
A microservices architecture requires dedicated ownership per service — 
typically 3–5 engineers per service minimum. With only 8 engineers, managing 
6+ independent services would consume the team in coordination overhead, 
leaving little capacity for feature development. A modular monolith allows 
the team to maintain clear internal boundaries without the operational burden 
of distributed systems.

**Quarterly Deployment Cycle**
The primary benefit of microservices is independent deployability — the 
ability to deploy one service without touching others. With quarterly 
deployments, this benefit is largely wasted. A monolith deployed every 
quarter carries significantly less operational risk than coordinating 
multi-service releases across a small team.

**Tight Domain Coupling**
Medical records, appointments, prescriptions, and lab results are deeply 
coupled. A doctor viewing a patient record needs simultaneous access to 
appointments, prescriptions, and lab history. Splitting these into separate 
services creates distributed joins — complex, slow, and dangerous in a 
medical context where incomplete data can affect clinical decisions.

**The One Exception: Emergency Notifications**
The emergency notification system is extracted as a standalone AWS Lambda 
function. This is justified because it has fundamentally different 
characteristics from the rest of the application:
- It must scale from zero to thousands of invocations instantly
- It has no persistent state
- It has no coupling to the core domain logic
- Its failure must never affect the main application

### Internal Module Boundaries
Although deployed as a single unit, the codebase is organised into 
clearly separated modules:
- Patient Records Module
- Appointment Scheduling Module
- Prescription Management Module
- Lab Results & Imaging Module
- Billing & Insurance Module
- Telemedicine Module

Each module owns its data access layer and exposes internal interfaces. 
This structure allows future extraction into microservices if the team 
grows or deployment frequency increases.

---

## 2. Communication Design

### Synchronous Interactions (Immediate Response Required)

| Interaction | Pattern | Justification |
|---|---|---|
| Appointment booking | Synchronous (REST) | Double-booking prevention requires a database lock and immediate confirmation |
| Prescription dispensing | Synchronous (REST) | Drug interaction check must complete before prescription is issued |
| Telemedicine session start | Synchronous (WebSocket) | Live video requires real-time bidirectional connection |
| Patient authentication | Synchronous (REST) | Access control decisions cannot be deferred |
| Lab result retrieval | Synchronous (REST) | Doctor expects immediate response when viewing results |

### Asynchronous Interactions (Eventual Consistency Acceptable)

| Interaction | Pattern | Tool | Justification |
|---|---|---|---|
| Billing & insurance claims | Async | SQS | Claims are processed by insurers over hours or days |
| Appointment reminders | Async | SNS | SMS/email delivery, no response needed |
| Lab result notifications | Async | SNS | Patient notified when results are ready |
| Audit log writes | Async | SQS FIFO | Logs must be ordered but need not block the request |
| Hospital system sync | Async | SQS + Lambda | External systems have their own SLAs |

### Emergency Notification System
Emergencies require a dedicated, isolated notification path that bypasses 
the main application entirely:

1. Emergency trigger fired (critical lab result, patient alert)
2. Lambda function invoked directly via EventBridge
3. SNS topic fans out simultaneously to:
   - On-call doctor via SMS (< 30 second delivery SLA)
   - Ward administrator dashboard (WebSocket push)
   - Mobile app push notification (APNs/FCM)
4. Unacknowledged alerts escalate automatically after 5 minutes
5. All alerts logged to DynamoDB with immutable timestamp

### Hospital System Integration
External hospital systems (HIS/EMR) are integrated via:
- **Inbound:** API Gateway → SQS → Lambda consumer → application database
- **Outbound:** Application → SQS → Lambda publisher → hospital API
- All messages are validated against HL7 FHIR schemas before processing
- Dead letter queues capture failed messages for manual review

---

## 3. Data Architecture

### Database Selection by Data Type

**Amazon RDS PostgreSQL 15 — Multi-AZ**
Used for: patient records, appointments, prescriptions, billing, user accounts

Justification: These entities have strict relational integrity requirements. 
A prescription cannot exist without a patient and a doctor. An appointment 
cannot exist without an available slot. ACID compliance is non-negotiable 
in a clinical context. Multi-AZ deployment provides automatic failover 
(typically 60–120 seconds) which is sufficient to meet the 99.5% uptime 
requirement.

**Amazon ElastiCache (Redis 7)**
Used for: doctor session state, telemedicine session tokens, appointment 
slot availability cache

Justification: Reading doctor availability from PostgreSQL on every 
scheduling request creates unnecessary load. Redis provides sub-millisecond 
reads for frequently accessed, short-lived data. Session tokens for 
telemedicine are stored here with a TTL matching the session duration.

**Amazon S3 — Intelligent Tiering**
Used for: medical imaging (X-rays, MRI scans, ultrasounds), lab result 
attachments, insurance documents

Justification: Medical images range from 50MB to 500MB. Storing binary 
objects in a relational database is an antipattern — it bloats the database 
and destroys query performance. S3 provides 99.999999999% durability and 
lifecycle policies automatically move images older than 90 days to S3 
Glacier for cost optimisation. Images are accessed via pre-signed URLs 
with 15-minute expiry — never exposed publicly.

**Amazon DynamoDB**
Used for: audit logs, emergency alert delivery records, notification history

Justification: Audit logs are write-heavy, append-only, and never updated. 
They are queried by patient ID or timestamp range — a perfect fit for 
DynamoDB's key-value model. Healthcare compliance requires immutable audit 
trails retained for 7 years. DynamoDB's on-demand pricing means cost scales 
directly with actual usage.

### Data Classification
Not all data carries equal sensitivity. Access controls and encryption 
policies are designed around three tiers:

| Tier | Data Types | Controls |
|---|---|---|
| High sensitivity | Diagnoses, prescriptions, lab results | KMS encryption, access logged per request, MFA required |
| Medium sensitivity | Appointment metadata, billing totals | Encrypted at rest, role-based access |
| Low sensitivity | Anonymised aggregate statistics | Cacheable, no PII |

### Backup & Disaster Recovery

- RDS automated backups: 35-day retention, point-in-time recovery enabled
- RDS snapshots: daily automated + manual before every quarterly deployment
- S3 versioning enabled on all imaging buckets
- S3 cross-region replication to a secondary region for imaging data
- DynamoDB point-in-time recovery enabled
- Recovery Time Objective (RTO): 2 hours
- Recovery Point Objective (RPO): 1 hour

---

## 4. Security Architecture

### Defence in Depth Model

**Layer 1 — Perimeter**
- AWS WAF on Application Load Balancer blocks SQLi, XSS, and 
  credential-stuffing attacks
- AWS Shield Standard protects against volumetric DDoS
- All traffic HTTPS only — ACM-managed TLS 1.2+ certificates
- HTTP requests rejected at ALB (not redirected)

**Layer 2 — Network Isolation**
- ECS tasks, RDS, and ElastiCache deployed in private subnets only
- No public IP addresses on any compute or database resource
- ALB is the only resource in a public subnet
- Security groups enforce least-privilege port access:
  - ALB → ECS: port 443 only
  - ECS → RDS: port 5432 only
  - ECS → Redis: port 6379 only
- VPC Flow Logs capture all accepted and rejected connections

**Layer 3 — Identity & Access**
- Amazon Cognito User Pools for patient and staff authentication
- MFA enforced for all doctors and administrators
- IAM task roles per ECS service — no hardcoded AWS credentials
- Role-based access control:
  - Patients access own records only
  - Doctors access assigned patients only
  - Administrators access anonymised data by default

**Layer 4 — Data Encryption**
- RDS encrypted at rest using AES-256 via AWS KMS
- S3 SSE-KMS on all imaging and document buckets
- ElastiCache in-transit encryption enabled
- TLS enforced between all ECS tasks and downstream services
- AWS Secrets Manager stores all database credentials and API keys
- Secrets rotated automatically every 30 days

**Layer 5 — Audit & Compliance**
- AWS CloudTrail logs every API call — immutable, 7-year retention
- AWS Config evaluates infrastructure against security rules continuously
- Alerts fire within minutes if any security group opens to 0.0.0.0/0
- All patient data access events written to DynamoDB audit log

---

## 5. Cloud Resource Planning

### Compute

**AWS ECS Fargate**
Chosen over EKS and EC2 for the following reasons:
- EKS requires dedicated Kubernetes expertise to manage control plane upgrades, node groups, and CNI plugins — consuming 2–3 of the 3 available DevOps engineers entirely
- EC2 requires OS patching, AMI management, and capacity planning
- Fargate removes all server management — the team defines a container and CPU/memory spec, AWS handles the rest
- For quarterly deployments, operational simplicity outweighs any performance advantage of Kubernetes

Task sizing:
- Application service: 1 vCPU, 2GB RAM (scales to 4 vCPU, 8GB under load)
- Telemedicine service: 2 vCPU, 4GB RAM (video processing overhead)

**AWS Lambda**
Used exclusively for the emergency notification service and hospital system integration consumers. Event-driven, stateless, scales to zero when not in use.

### Networking

- VPC: /16 CIDR (65,536 addresses)
- Public subnets (2 AZs): ALB only
- Private subnets (2 AZs): ECS tasks
- Isolated subnets (2 AZs): RDS, ElastiCache
- NAT Gateway: one per AZ for ECS outbound internet access
- Application Load Balancer with HTTPS listener
- Route 53 for DNS with health checks

### Cost Considerations
- ECS Fargate: pay per task per second — no idle EC2 costs
- RDS Multi-AZ: higher cost than single-AZ but required for 99.5% uptime
- S3 Intelligent Tiering: automatically moves cold imaging data to cheaper storage tiers
- ElastiCache cache.t3.medium: sufficient for session and availability caching
- NAT Gateway: most significant ongoing cost — minimised by keeping external API calls batched

---

## 6. Trade-offs Analysis

### Trade-off 1: Modular Monolith vs Microservices
**Decision:** Modular monolith

**What we gain:** Deployment simplicity, transactional data consistency, reduced operational overhead, faster development for a small team.

**What we give up:** Independent scaling of individual features, technology diversity per service, fault isolation between domains.

**Mitigation:** Module boundaries are enforced in code. If the team grows beyond 15 engineers or deployment frequency increases to weekly, individual modules can be extracted into services without a full rewrite. 
The database schema is designed with this future extraction in mind — each module's tables are prefixed and avoid cross-module foreign keys where possible.

### Trade-off 2: RDS Multi-AZ vs Aurora PostgreSQL
**Decision:** RDS Multi-AZ

**What we gain:** Lower cost (approximately 3× cheaper than Aurora), simpler operational model, sufficient performance for 20,000 patients.

**What we give up:** Aurora's faster failover (< 30 seconds vs 60–120 seconds for RDS), Aurora Serverless auto-scaling, and higher read throughput via read replicas.

**Mitigation:** The architecture is designed to allow migration to Aurora Serverless v2 if patient load grows beyond 100,000 users or if the 60–120 second failover window proves insufficient in practice. RDS snapshots make this migration straightforward.

### Trade-off 3: Single Region vs Multi-Region
**Decision:** Single region, Multi-AZ

**What we gain:** Dramatically lower operational complexity, lower cost, simpler data residency compliance.

**What we give up:** Protection against a full AWS regional outage 
(extremely rare but possible).

**Mitigation:** Multi-AZ deployment within a single region handles hardware failures and AZ-level outages, which are far more common than regional failures. 
Route 53 health checks redirect traffic automatically if an AZ becomes unavailable. The 99.5% uptime requirement (allows ~44 hours downtime per year) does not require multi-region redundancy. 
S3 cross-region replication protects imaging data independently of compute.