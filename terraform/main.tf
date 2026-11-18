data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name = "devops-assessment-${var.environment}"
}

# ---------- Logs ----------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/devops-assessment/${var.environment}"
  retention_in_days = var.log_retention_days
}

# ---------- IAM (least privilege, no static keys) ----------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-ec2"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Lets the CD pipeline run deploy commands through SSM (no SSH, no open port 22).
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Write to this one log group only. The image is public on GHCR, so no registry permissions are needed.
data "aws_iam_policy_document" "logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "cloudwatch-logs-write"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-ec2"
  role = aws_iam_role.app.name
}

# ---------- Network ----------
resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "App port only; no SSH (access through SSM)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App HTTP"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr
  }

  egress {
    description = "Outbound for image pulls, CloudWatch and SSM"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- Compute ----------
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    image_repo  = var.image_repo
    image_tag   = var.image_tag
    log_group   = aws_cloudwatch_log_group.app.name
    region      = var.region
    environment = var.environment
    deploy_b64  = base64encode(file("${path.module}/../scripts/deploy.sh"))
  })

  depends_on = [
    aws_iam_role_policy.logs,
    aws_iam_role_policy_attachment.ssm,
  ]

  tags = {
    Name = local.name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
