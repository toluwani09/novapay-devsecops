# NovaPay Threat Model

## Scope

This threat model covers the NovaPay wallet service and its staging infrastructure. The environment consists of a containerized FastAPI application running on an EC2 instance, an Amazon RDS PostgreSQL database in private subnets, AWS Secrets Manager, IAM, and the GitHub Actions deployment pipeline.

The STRIDE methodology is used to identify the main security threats and the controls implemented in the project.

## STRIDE Analysis

| Category 			| Threat											 | Mitigation |

| Spoofing			| An unauthorized user or process attempts to access infrastructure or impersonate the application. | EC2 uses SSH key authentication for deployment. AWS access is controlled through IAM roles and least-privilege permissions. |
| Tampering 			| Application code, container images, or deployment artifacts could be modified maliciously. 	| GitHub Actions performs linting, tests, SAST, dependency scanning, container vulnerability scanning, and secret scanning before staging deployment. Deployment occurs only after the required pipeline checks succeed. |
| Repudiation			| Actions or application activity could occur without sufficient evidence for investigation. 	| The application produces structured JSON logs containing the service and event information. Git and GitHub Actions also provide an auditable history of code and deployment changes. |
| Information Disclosure 	| Wallet data, database credentials, or application secrets could be exposed. 			| RDS is deployed in private subnets and database access is restricted to the application security group. Secrets are not stored in the repository and AWS Secrets Manager is used for secret storage. |
| Denial of Service 		| Excessive requests could affect the availability of the wallet service. 			| Health and readiness endpoints provide service-status visibility. Prometheus metrics and the example error-rate alert rule provide operational visibility into abnormal application behaviour. |
| Elevation of Privilege 	| A compromised application or container could attempt to obtain higher privileges. 		| The application container runs as a non-root user. The EC2 IAM role grants only the required Secrets Manager access to the specific NovaPay secret rather than broad AWS permissions. |

## Key Security Boundaries

- The NovaPay application runs inside a non-root Docker container.
- The EC2 compute instance is located in the public subnet.
- Amazon RDS is isolated in private subnets.
- Database access is allowed only from the NovaPay compute security group.
- Application secrets are represented through AWS Secrets Manager rather than plaintext values in the repository.
- GitHub Actions security checks must pass before deployment to staging.

## Residual Risks

The staging application is publicly reachable on port 8000 and SSH is exposed for the staging deployment workflow. These are staging-specific implementation decisions and would require tighter network restrictions in a production environment.

The wallet endpoint currently returns demonstration data and is not connected to the provisioned RDS database.