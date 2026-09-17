# NovaPay DevOps / DevSecOps Take-Home

**Tolulope Philip Olalere**  
Cloud / DevOps Engineer  
AWS Certified Solutions Architect – Associate | Kubernetes and Cloud Native Associate (KCNA)

# Description
NovaPay is a minimal wallet microservice used to demonstrate a secure, observable, auditable, and reproducible deployment workflow.

The focus of this implementation is the engineering around the service: secure containerization, security-gated CI/CD, Infrastructure as Code, secrets handling, least-privilege IAM, observability, threat modelling, incident response and deployment to a real AWS staging environment.

---

## 1. Application

The NovaPay wallet service is implemented with FastAPI and exposes the following endpoints:

| Endpoint      | Purpose |
| `GET /health` | Application health check |
| `GET /ready` | Application readiness check |
| `GET /version` | Returns the application version |
| `GET /wallets/{id}` | Returns demonstration wallet information |
| `GET /metrics` | Exposes Prometheus metrics |

Example wallet response:

```json
{
  "id": "123",
  "balance_kobo": 500000
}
```

The wallet response is deliberately static because application functionality is not the focus of this exercise.

---

## 2. Architecture

The staging environment is deployed to AWS using Terraform.

![NovaPay Architectural Diagram](Images/NovaPay%20Architectural%20Diagram.jpeg)

```

### Network Boundaries

The VPC uses:
10.0.0.0/16

The subnet design is:
Public subnet:     10.0.1.0/24
Private subnet 1:  10.0.2.0/24
Private subnet 2:  10.0.3.0/24

The EC2 staging compute instance runs in the public subnet.

The PostgreSQL RDS instance uses the private database subnets and is configured as not publicly accessible.

Database access on TCP port `5432` is permitted only from the NovaPay compute security group.

The application security group exposes port `8000` for access to the staging service.

SSH is used for the GitHub Actions staging deployment.

### Network Isolation Evidence

The AWS staging environment contains one public subnet and two private subnets as defined by the Terraform configuration.

![Public and private subnet deployment](Images/1%20pub%20and%202%20priv%20subnets%20created.JPG)

---

## 3. Real vs Demonstration Components

This implementation uses a real AWS staging environment, although the instruction make it optional, I decided to stage a real staging environment to ensure that i have a correct and valid insfrastucture.

The following infrastructure was provisioned using Terraform:

- VPC
- Public subnet
- Two private subnets
- Internet Gateway
- Route table and public routing
- EC2 staging compute instance
- RDS PostgreSQL database
- AWS Secrets Manager resource
- Security groups
- EC2 IAM role
- EC2 instance profile

Terraform was successfully applied to AWS in `us-east-1`.

The EC2 instance runs Docker and hosts the deployed NovaPay container.

The RDS database is a real managed datastore deployed in private subnets. However, the current `GET /wallets/{id}` endpoint returns demonstration data and does not query the RDS database.

RDS is therefore used in this exercise to demonstrate the required managed datastore, network isolation, and access-control design without unnecessarily expanding the trivial application implementation.

Terraform state is maintained locally and excluded from Git.

---

## 4. Secure Containerization

NovaPay uses a multi-stage Docker build.

The build stage installs Python dependencies separately from the final runtime environment.

The runtime image is based on:
python:3.13-slim

The final container creates and runs under the dedicated user:
appuser

The runtime identity was independently verified using:

```bash
docker exec novapay id
docker exec novapay whoami
```

The container reported UID `1000` and `appuser`, confirming that the application does not run as root.

### Non-Root Runtime Evidence

![Non-root container verification](Images/confirming%20that%20the%20container%20is%20not%20running%20as%20a%20root%20user.JPG)

No application credentials or secrets are copied into the image.

The runtime stage also installs available operating-system security updates before producing the final image.

---

## 5. CI/CD Security Pipeline

GitHub Actions implements the NovaPay CI/CD pipeline.

The pipeline executes the following sequence:

Checkout Repository
        |
        v
Lint - Ruff
        |
        v
Unit Tests - Pytest
        |
        v
SAST - Bandit
        |
        v
Dependency Vulnerability Scan - pip-audit
        |
        v
Build Docker Image
        |
        v
Container Vulnerability Scan - Trivy
        |
        v
Secret Scan - Gitleaks
        |
        v
Deploy to Staging
        |
        v
Verify /health
```

### Lint

Ruff performs linting against the Python application.

### Unit Tests

Pytest validates the application endpoints.

The current tests cover:

- `/health`
- `/ready`
- `/version`
- `/wallets/{id}`

### SAST

Bandit performs static application security testing against the Python source.

### Dependency Vulnerability Scan

`pip-audit` scans the dependencies declared in:

app/requirements.txt
```

### Container Vulnerability Scan

Trivy scans the built NovaPay container image.

The pipeline is configured to fail when a `CRITICAL` container vulnerability is detected.

This gate was exercised during implementation when Trivy detected three CRITICAL vulnerabilities inherited from the runtime base image.

The pipeline failed and prevented deployment until the vulnerabilities were remediated.

### Security Gate Evidence

![Critical vulnerability gate failure](Images/vulnerability%20scan%20failed%20as%20requested.JPG)

The underlying vulnerability was corrected and the pipeline was rerun without reducing the Trivy severity threshold or bypassing the security gate.

### Secret Scan

Gitleaks scans the repository and Git history for secrets.

A detected secret causes the security check to fail.

No plaintext application credentials are intentionally stored in the repository.

### Staging Deployment

Deployment occurs only for pushes to `main` after the required pipeline checks have succeeded.

The EC2 staging host and SSH private key are supplied through GitHub Actions secrets:

STAGING_HOST
STAGING_SSH_KEY

The SSH private key is not stored in the repository.

The pipeline packages the same Docker image that passed the Trivy scan and transfers that image to the staging EC2 instance.

The image is loaded on EC2 and started as the `novapay-wallet` container.

The final pipeline stage verifies:

```
GET /health
```

A failed required pipeline stage prevents staging deployment.

### Successful Staging Deployment

The completed GitHub Actions pipeline passed the required quality and security gates before deploying the scanned container image to the staging EC2 instance. The deployment concluded with successful health verification.

![Successful NovaPay security pipeline](Images/All%20green%20NovaPay%20Security%20pipeline.JPG)

---

## 6. Infrastructure as Code

Terraform configuration is stored in:

terraform/


The configuration is separated by responsibility:

providers.tf
variables.tf
network.tf
compute.tf
database.tf
secrets.tf
iam.tf


The AWS provider is constrained to:

```hcl
version = "~> 6.0"
```

The staging environment uses:

```
us-east-1
```

### Validating the Infrastructure

From the Terraform directory:

```bash
terraform fmt
terraform validate
terraform plan
```

### Applying the Infrastructure

```bash
terraform apply
```

The infrastructure used for this submission was applied to the AWS staging environment.

### Terraform Apply Evidence

![Terraform staging apply](Images/terraform%20apply%20for%20staging.JPG)

### Managed Datastore Evidence

Amazon RDS PostgreSQL was deployed as the managed datastore using the private database subnets.

![NovaPay staging RDS](Images/staging%20rds%20deployed.JPG)

### Terraform State

Terraform state is maintained locally for this exercise.

Generated and local Terraform files are excluded from Git, including:

.terraform/
*.tfstate
*.tfstate.*

The Terraform dependency lock file is retained in the repository to support consistent provider selection.

---

## 7. IAM and Least Privilege

The EC2 instance uses an IAM role instead of embedding AWS credentials in the application or repository.

The application instance role is permitted to perform:

```
secretsmanager:GetSecretValue
```

against the specific NovaPay Secrets Manager resource.

The IAM policy does not use wildcard actions or wildcard resources.

Least privilege was also demonstrated during implementation when the following command was attempted from the EC2 instance:

```bash
aws ec2 describe-instances
```

AWS returned:

```
UnauthorizedOperation
```

The EC2 role was not modified to permit this operation because enumerating EC2 instances is not required by the NovaPay application.

The administrative command was instead performed from the separate AWS CLI context used to manage the infrastructure.

---

## 8. Secrets Management

No application secrets are intentionally stored in plaintext in the repository or Git history.

AWS Secrets Manager provides the NovaPay application secret resource.

The RDS master password is managed through the AWS-managed RDS secret mechanism rather than being declared as plaintext in Terraform source.

The staging deployment SSH private key is stored in GitHub Actions Secrets.

Local sensitive files such as the staging SSH private key are excluded from Git.

Gitleaks provides the CI/CD enforcement gate against accidental secret exposure.

---

## 9. Credential Rotation Procedure

If a credential is suspected to have leaked, it is treated as compromised even if unauthorized use has not yet been confirmed.

The response procedure is:

1. Identify the exposed credential and the systems that use it.
2. Disable, revoke, or invalidate the exposed credential.
3. Generate or configure a replacement credential.
4. For an application secret, replace the affected value through AWS Secrets Manager.
5. For the staging deployment SSH key, replace the authorized key used by the EC2 staging instance and update `STAGING_SSH_KEY` in GitHub Actions Secrets.
6. Update the consuming application or deployment configuration to use the replacement credential.
7. Verify that the replacement credential works correctly.
8. Confirm that the old credential can no longer be used.
9. If a credential was accidentally committed, remove it from repository history as appropriate. Removal alone is not considered remediation because the credential must still be rotated.
10. Rerun Gitleaks and the required CI/CD security checks.
11. Review available logs and activity information for evidence of unauthorized use.
12. Record the incident and remediation actions.

A leaked credential is therefore rotated rather than simply removed from source code.

---

## 10. Observability

NovaPay provides application-level observability through structured JSON logging, health and readiness endpoints, and Prometheus metrics.

### Structured JSON Logs

Application events are emitted in structured JSON.

Example:

```json
{
  "level": "INFO",
  "service": "novapay-wallet",
  "event": "wallet_retrieved",
  "wallet_id": "123"
}
```

### Health and Readiness

The application exposes:

```
GET /health
GET /ready
```

### Prometheus Metrics

Prometheus-compatible metrics are exposed through:

```
GET /metrics
```

Custom NovaPay metrics include:

```
novapay_wallet_requests_total
novapay_wallet_errors_total
```

### Prometheus Metric Evidence

The custom request counter was verified through the `/metrics` endpoint.

![NovaPay Prometheus request counter](Images/request%20counter.JPG)

### Error-Rate Alert

The example Prometheus alerting rule is stored in:

```
observability/alerts.yml
```

The rule evaluates:

```
rate(novapay_wallet_errors_total[5m])
/
rate(novapay_wallet_requests_total[5m])
```

and raises:

```
NovaPayHighErrorRate
```

when the wallet error rate exceeds 5% for five minutes.

The alert rule is supplied as the required example configuration. A Prometheus or Alertmanager deployment is not part of this implementation.

---

## 11. Running the Application Locally

From the repository root:

```bash
cd app
python -m pip install -r requirements.txt
```

Start the application:

```bash
python -m uvicorn main:app --reload
```

The service is available at:

```
http://localhost:8000
```

Example requests:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/ready
curl http://localhost:8000/version
curl http://localhost:8000/wallets/123
curl http://localhost:8000/metrics
```

---

## 12. Running the Container Locally

From the repository root:

```bash
docker build -t novapay-wallet .
```

Run the container:

```bash
docker run --rm -p 8000:8000 --name novapay-wallet novapay-wallet
```

Verify the service:

```bash
curl http://localhost:8000/health
```

Verify the runtime identity:

```bash
docker exec novapay-wallet whoami
docker exec novapay-wallet id
```

The expected runtime user is:

```
appuser
```

---

## 13. Running the CI Security Checks Locally

Install the application and security-analysis dependencies:

```bash
python -m pip install -r app/requirements.txt
python -m pip install ruff bandit pip-audit
```

### Lint

```bash
ruff check app/
```

### Unit Tests

```bash
cd app
python -m pytest -v
cd ..
```

### SAST

```bash
bandit -r app/ -x app/test_main.py
```

### Dependency Vulnerability Scan

```bash
pip-audit -r app/requirements.txt
```

### Building the Container Image

```bash
docker build -t novapay-wallet:local .
```

### Container Vulnerability Scan

With Trivy installed:

```bash
trivy image --severity CRITICAL --exit-code 1 novapay-wallet:local
```

### Secret Scan

With Gitleaks installed:

```bash
gitleaks detect --source . --log-opts="--all" --redact --verbose
```

A CRITICAL container vulnerability or detected secret should result in a failing security check.

The authoritative CI/CD implementation is defined in:

```
.github/workflows/ci-cd.yml
```

---

## 14. Security Documentation

### STRIDE Threat Model

The threat model is documented in:

```
THREAT_MODEL.md
```

It evaluates NovaPay using the STRIDE categories:

- Spoofing
- Tampering
- Repudiation
- Information Disclosure
- Denial of Service
- Elevation of Privilege

The identified threats are mapped to controls implemented in the NovaPay staging environment.

### Incident Response Runbook

The incident response procedure is documented in:

```
RUNBOOK.md
```

The runbook addresses suspected unauthorized access to the wallet database and covers:

- Identification and assessment
- Containment
- Evidence preservation
- Eradication
- Recovery
- Post-incident review

---

## 15. AI Usage

AI-assisted engineering work is documented in:

```
AI_USAGE.md
```

The document records the AI tool used, concrete prompts and results, validation performed on generated output and engineering decisions made after validation.

One documented example covers an AI-assisted Dockerfile that satisfied the structural container requirements but produced an image containing inherited CRITICAL vulnerabilities.

The Trivy pipeline gate identified the vulnerabilities, deployment was blocked, the underlying issue was remediated, and the same security gate was rerun successfully without weakening the security threshold.

---

## 16. Repository Structure

```
NovaPay/
|
|-- .github/
|   `-- workflows/
|       `-- ci-cd.yml
|
|-- app/
|   |-- main.py
|   |-- requirements.txt
|   `-- test_main.py
|
|-- observability/
|   `-- alerts.yml
|
|-- terraform/
|   |-- providers.tf
|   |-- variables.tf
|   |-- network.tf
|   |-- compute.tf
|   |-- database.tf
|   |-- secrets.tf
|   `-- iam.tf
|
|-- Images/
|
|-- Dockerfile
|-- README.md
|-- THREAT_MODEL.md
|-- RUNBOOK.md
|-- AI_USAGE.md
`-- .gitignore
```

---

## 17. Implementation Evidence

The `Images/` directory contains screenshots captured during implementation and validation.

The evidence includes:

- Successful GitHub Actions security pipeline
- Successful staging deployment
- Pipeline blocking a container containing CRITICAL vulnerabilities
- Terraform initialization, planning, and application
- VPC and subnet provisioning
- EC2 staging deployment
- RDS staging deployment
- Docker image build and execution
- Non-root container verification
- Structured application logs
- Application endpoint verification
- Prometheus metric verification

The screenshots supplement the reproducible source code, Terraform configuration, pipeline definition, and security documentation contained in the repository.

---

## 18. Assumptions and Limitations

This repository represents the staging implementation for the take-home exercise.

The following assumptions and limitations are documented explicitly:

- The wallet endpoint returns demonstration data and is not connected to the provisioned RDS database.
- Terraform was applied to a real AWS staging environment.
- Terraform state is maintained locally and is not committed to Git.
- The staging application is exposed on port 8000.
- GitHub Actions uses SSH to deploy the scanned container image to the staging EC2 instance.
- SSH ingress is available for the staging deployment workflow. This is a staging-specific implementation decision.
- The Prometheus alert rule is provided as the required example configuration; a Prometheus/Alertmanager deployment is not included.
- No plaintext application secret is intentionally stored in the repository.
- Infrastructure and application choices were deliberately limited to the requirements of the exercise rather than introducing additional platform components.

---

## 19. Security Controls Summary

The implementation enforces the following key controls.

### No Plaintext Secrets in the Repository

Application and deployment secrets are kept outside source control, and Gitleaks scans the repository and Git history.

### Least-Privilege IAM

The EC2 application role is restricted to the specific Secrets Manager action and resource required by the design. It does not use wildcard IAM actions or resources.

### Non-Root Container

The application runs as `appuser` rather than root, and this was verified against the running container.

### Critical Vulnerabilities Block Deployment

Trivy is configured to fail the pipeline when a CRITICAL container vulnerability is detected.

This behaviour was demonstrated during implementation rather than being documented only as an intended control.

### Secret Detection Blocks the Pipeline

Gitleaks is part of the required pipeline before staging deployment.

### Security Gates Precede Deployment

The staging deployment occurs only after the required linting, testing, SAST, dependency scanning, container scanning, and secret scanning stages succeed.


