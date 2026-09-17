# NovaPay Incident Response Runbook

## Scenario

This runbook describes the response process when unauthorized access to the NovaPay wallet database is suspected.

## 1. Identify and Assess

- Confirm the reported or detected suspicious activity.
- Determine when the activity started and what systems may be affected.
- Review available application logs and AWS activity information for evidence of unauthorized access.
- Identify the credentials, IAM roles, application components, or network paths that may have been involved.
- Record the findings and actions taken during the investigation.

## 2. Contain

- Restrict access to the affected database and application components where necessary.
- Review the RDS security group and confirm that PostgreSQL access on port 5432 is limited to the NovaPay compute security group.
- Disable or revoke any compromised credentials.
- If the application secret is suspected to be compromised, rotate it in AWS Secrets Manager.
- If an AWS credential is compromised, disable the affected credential and replace it with a new least-privilege credential.
- Prevent further deployment until the source of the incident has been identified.

## 3. Preserve Evidence

Before making unnecessary changes, preserve information required for investigation.

- Preserve relevant application logs.
- Preserve relevant GitHub Actions deployment logs.
- Record suspicious requests, timestamps, affected resources, and observed behaviour.
- Record all containment and remediation actions.

## 4. Eradicate

- Remove any unauthorized access or configuration discovered during the investigation.
- Remove compromised credentials and replace them with new credentials.
- Correct any security group, IAM, application, or deployment configuration that contributed to the incident.
- Run the CI/CD security checks again, including SAST, dependency scanning, container vulnerability scanning, and secret scanning.

## 5. Recover

- Confirm that the database security group allows access only from the intended NovaPay compute security group.
- Confirm that required secrets have been rotated.
- Verify that the application container is running as a non-root user.
- Redeploy the application through the approved GitHub Actions pipeline.
- Verify the `/health` and `/ready` endpoints.
- Verify application functionality before returning the service to normal operation.

## 6. Post-Incident Review

- Document the root cause and impact of the incident.
- Document which credentials, systems, or data were affected.
- Record the actions taken to contain and recover from the incident.
- Identify any control that failed or needs improvement.
- Update the runbook or deployment configuration where necessary.