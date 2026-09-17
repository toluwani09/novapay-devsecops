resource "aws_secretsmanager_secret" "novapay" {
  name        = "${var.project_name}-${var.environment}-application-secret"
  description = "NovaPay staging application secret"

  tags = {
    Name        = "${var.project_name}-${var.environment}-application-secret"
    Environment = var.environment
  }
}