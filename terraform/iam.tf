data "aws_iam_policy_document" "compute_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "novapay_compute" {
  name               = "${var.project_name}-${var.environment}-compute-role"
  assume_role_policy = data.aws_iam_policy_document.compute_assume_role.json
}

data "aws_iam_policy_document" "novapay_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.novapay.arn
    ]
  }
}

resource "aws_iam_role_policy" "novapay_secrets" {
  name   = "${var.project_name}-${var.environment}-secrets-policy"
  role   = aws_iam_role.novapay_compute.id
  policy = data.aws_iam_policy_document.novapay_secrets.json
}

resource "aws_iam_instance_profile" "novapay" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.novapay_compute.name
}