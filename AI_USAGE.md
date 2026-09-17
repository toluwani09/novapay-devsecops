# AI Usage

## AI Tool Used

I used ChatGPT as an engineering assistant during the NovaPay DevOps/DevSecOps exercise. I used it mainly for configuration drafting, implementation review, troubleshooting, and checking proposed solutions against the requirements of the exercise.

I did not treat AI-generated output as automatically correct or secure. I reviewed and validated the generated output using unit tests, Terraform validation and planning, SAST, dependency scanning, container vulnerability scanning, secret scanning, and actual staging deployment.

The prompts below consolidate the instructions and technical constraints I provided during the relevant AI-assisted exchanges.

---

## Prompt 1: Dockerfile and Container Security

### Prompt / Instructions

I have a FastAPI wallet service running on Python 3.13 with the application entry point in `app/main.py` and dependencies in `app/requirements.txt`.

Create a Dockerfile that meets the following requirements:

- Use a multi-stage build.
- Use a minimal Python 3.13 runtime image.
- Install dependencies in the build stage and copy them into the runtime stage.
- Copy only the application file required at runtime.
- Create a dedicated non-root user called `appuser`.
- Run the final container as `appuser`.
- Expose port 8000.
- Start the service using `python -m uvicorn main:app --host 0.0.0.0 --port 8000`.
- Do not copy `.env`, credentials, SSH keys, or other secrets into the image.
- Do not add components that are not required for this application.

### AI Result

The generated Dockerfile used `python:3.13-slim` for both the build and runtime stages. Dependencies were installed in the build stage and copied into the runtime image. The runtime stage created a dedicated `appuser` and used the Dockerfile `USER` instruction to ensure the application did not run as root.

I built and ran the container and independently verified the runtime identity using:

```bash
docker exec novapay id
docker exec novapay whoami
```

The result showed UID 1000 and `appuser`, confirming that the application was running as a non-root user.

### Security Issue Identified

Although the AI-generated Dockerfile appeared secure from a configuration review, the resulting image inherited vulnerable operating-system packages from the base image.

When the image reached the Trivy container-scanning stage of the GitHub Actions pipeline, the pipeline failed because three CRITICAL vulnerabilities were detected in Debian's `perl-base` package:

- CVE-2026-13221
- CVE-2026-42496
- CVE-2026-8376

The installed version was `5.40.1-6`, while the fixed version was `5.40.1-6+deb13u1`.

This demonstrated that satisfying Dockerfile security practices such as a minimal image and non-root execution did not guarantee that the resulting image was free from known vulnerabilities.

I corrected the runtime stage to install available operating-system security updates:

```dockerfile
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*
```

I rebuilt the image and reran the same pipeline. The CRITICAL vulnerabilities were no longer reported and the Trivy gate passed.

I deliberately did not use `continue-on-error`, reduce the Trivy severity threshold, or disable the scan. I fixed the underlying vulnerability and allowed the existing security gate to validate the remediation.

This was an important example of why I treated AI-generated configuration as a starting point that still required independent security validation.

---

## Prompt 2: Terraform Staging Infrastructure and Least-Privilege IAM

### Prompt / Instructions

Generate Terraform for an AWS staging environment called `novapay-staging`.

The implementation must contain only the infrastructure required for this exercise:

- One VPC using `10.0.0.0/16`.
- One public subnet using `10.0.1.0/24`.
- Two private subnets using `10.0.2.0/24` and `10.0.3.0/24` in separate Availability Zones.
- An Internet Gateway and public route for the public subnet.
- One Amazon Linux 2023 `t3.micro` EC2 instance in the public subnet as the compute target.
- An encrypted PostgreSQL RDS `db.t3.micro` instance using the two private subnets.
- The RDS instance must not be publicly accessible.
- PostgreSQL port 5432 must be reachable only from the EC2 compute security group.
- Create an AWS Secrets Manager resource for the NovaPay application secret without putting a secret value in Terraform source.
- Create an EC2 IAM role and instance profile.
- The EC2 IAM policy must allow only `secretsmanager:GetSecretValue` against the ARN of the specific NovaPay application secret.
- Do not use `"*"` for IAM actions or resources.
- Use AWS provider version `~> 6.0` and region `us-east-1`.
- Separate the Terraform into logical files for providers, variables, networking, compute, database, secrets, and IAM.
- Do not introduce EKS, ECS, Lambda, NAT Gateway, load balancers, or other infrastructure outside these requirements.

### AI Result

The generated configuration formed the basis of the Terraform implementation in the repository.

The infrastructure included:

- VPC and subnet isolation
- Public EC2 compute target
- Private RDS PostgreSQL database
- AWS Secrets Manager resource
- Security groups
- EC2 IAM role
- EC2 instance profile

The RDS security group restricted PostgreSQL port 5432 to the NovaPay compute security group.

The EC2 IAM policy was restricted to:

```text
secretsmanager:GetSecretValue
```

against the ARN of the specific NovaPay application secret rather than using a wildcard resource.

### Validation and Engineering Judgment

I did not apply the AI-generated Terraform immediately.

I first ran:

```bash
terraform fmt
terraform validate
terraform plan
```

I reviewed the Terraform plan before applying the infrastructure and specifically checked the IAM configuration for wildcard actions and resources.

After validation, I ran:

```bash
terraform apply
```

and provisioned the staging infrastructure in AWS.

The least-privilege design was later demonstrated when I attempted to execute:

```bash
aws ec2 describe-instances
```

from the EC2 instance.

AWS returned `UnauthorizedOperation` because the instance role did not have permission to perform `ec2:DescribeInstances`.

I did not add the permission simply to make the command work because the NovaPay application did not require it. I instead ran the administrative command from my separate AWS CLI context.

This provided a practical confirmation that the application instance was not being granted unnecessary AWS permissions.

---

## Prompt 3: Security-Gated Deployment to Staging

### Prompt / Instructions

I already have a GitHub Actions pipeline for NovaPay containing the following stages:

1. Ruff linting
2. Pytest unit tests
3. Bandit SAST
4. pip-audit dependency vulnerability scanning
5. Docker image build
6. Trivy container scanning configured to fail on CRITICAL vulnerabilities
7. Gitleaks secret scanning across the repository and Git history

Extend the pipeline with the staging deployment required by the exercise.

The existing EC2 staging server runs Docker and is reachable through SSH. Do not introduce ECR, ECS, EKS, or another deployment platform.

The exact Docker image that passed the Trivy scan must be transferred to EC2 instead of rebuilding the application on the staging server.

Store the EC2 host and SSH private key in GitHub Actions secrets named `STAGING_HOST` and `STAGING_SSH_KEY`.

The deployment must:

- Configure SSH.
- Package the already-scanned Docker image.
- Copy the image to the staging EC2 instance.
- Load the image on EC2.
- Remove the previous `novapay-wallet` container if one exists.
- Start the new container on port 8000.
- Verify the deployment through `/health`.
- Run staging deployment only for pushes to `main`.
- Prevent deployment when an earlier required security check fails.
- Do not disable or bypass any existing security gate.

### AI Result

The deployment stages were added after the required security scans.

The workflow packages the same Docker image that passed the Trivy scan, transfers it to the staging EC2 instance through SSH, loads the image, starts the `novapay-wallet` container, and verifies the deployment through the `/health` endpoint.

The EC2 host and SSH private key are supplied through GitHub Actions secrets instead of being stored in the repository.

### Validation and Troubleshooting

The first updated pipeline did not reach staging deployment because the secret-scan step returned exit code 127.

Gitleaks itself reported:

```text
14 commits scanned.
no leaks found
```

I investigated the output rather than assuming Gitleaks had detected a secret.

The actual failure was an accidental `//This` line inside the shell block. Bash attempted to execute the line as a command because `//` is not valid Bash comment syntax.

I removed the invalid line rather than changing or bypassing Gitleaks.

The next pipeline completed successfully through:

- Secret scanning
- SSH configuration
- Container image packaging
- Transfer to staging
- Staging deployment
- Health verification

This confirmed two important behaviours:

1. A failed required pipeline step prevents deployment.
2. Staging deployment occurs only after the required security checks have succeeded.

---

## AI Review and Validation Approach

Throughout the exercise, I treated AI-generated output in the same way I would treat an unreviewed technical contribution. It had to be understood, reviewed, tested, and validated before becoming part of the final implementation.

My validation process included:

1. Reviewing generated code and configuration against the exercise requirements.
2. Running application unit tests.
3. Running `terraform fmt`, `terraform validate`, and `terraform plan` before infrastructure changes.
4. Reviewing IAM permissions for unnecessary access and wildcard permissions.
5. Running SAST and dependency vulnerability scanning.
6. Scanning the built container for CRITICAL vulnerabilities.
7. Scanning the repository and Git history for secrets.
8. Preventing staging deployment when a required security gate failed.
9. Deploying only the container image that passed the required security checks.
10. Verifying the deployed application through its `/health` endpoint.

The most significant lesson from the AI-assisted work came from the Dockerfile. The generated configuration appeared secure at source level because it used a minimal base image, multi-stage build, and non-root execution. However, automated scanning still identified CRITICAL vulnerabilities inherited from the base image.

This reinforced my approach to AI-assisted DevOps work: AI can accelerate implementation and troubleshooting, but generated output must still be independently reviewed and validated through testing, security controls, and observed deployment results.