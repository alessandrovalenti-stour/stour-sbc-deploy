provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

data "aws_vpc" "selected" {
  id = var.existing_vpc_id
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

# ---------------------------
# NOTE:
# We DO NOT create VPC/Subnets/IGW/Routes here.
# We attach resources to the existing "non-production" VPC and its public subnets.
# ---------------------------

# --- Security Group (in existing VPC) ---
resource "aws_security_group" "sbc" {
  name        = "${var.project}-sbc-sg"
  description = "SIP/RTP/SSH for LibreSBC PoC"
  vpc_id      = var.existing_vpc_id

  # SSH (restricted to internal 10.0.0.0/8)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # SIP UDP 5060
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SIP TCP 5060
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SIP TLS TCP 5061 (optional)
  dynamic "ingress" {
    for_each = var.enable_sip_tls ? [1] : []
    content {
      from_port   = 5061
      to_port     = 5061
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }



  # RTP range UDP
  ingress {
    from_port   = var.rtp_port_min
    to_port     = var.rtp_port_max
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # LibreUI access from management subnet and internal VPC
  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic from Controller
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.controller.id]
  }

  tags = {
    Name        = "${var.project}-sbc-sg"
    Environment = "non-production"
  }
}

# --- Security Group for Controller ---
resource "aws_security_group" "controller" {
  name        = "${var.project}-controller-sg"
  description = "Security group for the WebGUI controller"
  vpc_id      = var.existing_vpc_id

  # SSH access (restricted to internal 10.0.0.0/8)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # WebGUI access (FastAPI default 8000, plus standard web ports)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-controller-sg"
    Environment = "non-production"
  }
}

# --- IAM for EIP reassociation ---
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eip_failover" {
  name               = "${var.project}-eip-failover-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

data "aws_iam_policy_document" "eip_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eip_failover" {
  name   = "${var.project}-eip-failover-policy"
  policy = data.aws_iam_policy_document.eip_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.eip_failover.name
  policy_arn = aws_iam_policy.eip_failover.arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.eip_failover.name
}

# --- Debian 12 AMI ---
data "aws_ami" "debian_12" {
  most_recent = true
  owners      = ["136693071363"] # Debian official

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- EC2 instances (in existing public subnets) ---
resource "aws_instance" "sbc_a" {
  ami                         =  data.aws_ami.debian_12.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_a_id
  vpc_security_group_ids      = [aws_security_group.sbc.id]
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.sbc_root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project}-sbc-a"
    Role        = "libresbc"
    Node        = "A"
    AZ          = "eu-west-2a"
    Environment = "non-production"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
}

resource "aws_instance" "sbc_b" {
  ami                         =  data.aws_ami.debian_12.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_b_id
  vpc_security_group_ids      = [aws_security_group.sbc.id]
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.sbc_root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project}-sbc-b"
    Role        = "libresbc"
    Node        = "B"
    AZ          = "eu-west-2b"
    Environment = "non-production"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
}

resource "aws_instance" "controller" {
  ami                         = data.aws_ami.debian_12.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_a_id
  vpc_security_group_ids      = [aws_security_group.controller.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.controller_root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project}-controller"
    Role        = "controller"
    Environment = "non-production"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
}

# --- Elastic IP "VIP" ---
resource "aws_eip" "vip" {
  domain = "vpc"
  tags = {
    Name        = "${var.project}-vip"
    Environment = "non-production"
  }
}

# Associate EIP initially to node A
resource "aws_eip_association" "vip_to_a" {
  allocation_id = aws_eip.vip.id
  instance_id   = aws_instance.sbc_a.id
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

resource "aws_cloudwatch_metric_alarm" "sbc_a_cpu_high" {
  alarm_name          = "${var.project}-sbc-a-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.sbc_a.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "sbc_b_cpu_high" {
  alarm_name          = "${var.project}-sbc-b-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.sbc_b.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "controller_cpu_high" {
  alarm_name          = "${var.project}-controller-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.controller.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "sbc_a_status_check_failed" {
  alarm_name          = "${var.project}-sbc-a-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    InstanceId = aws_instance.sbc_a.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "sbc_b_status_check_failed" {
  alarm_name          = "${var.project}-sbc-b-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    InstanceId = aws_instance.sbc_b.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "controller_status_check_failed" {
  alarm_name          = "${var.project}-controller-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    InstanceId = aws_instance.controller.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# --- Generate Ansible inventory (optional, handy) ---
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"
  content  = <<-EOT
  [libresbc]
  sbc_a ansible_host=${aws_instance.sbc_a.public_ip} private_ip=${aws_instance.sbc_a.private_ip} priority=110 state=MASTER
  sbc_b ansible_host=${aws_instance.sbc_b.public_ip} private_ip=${aws_instance.sbc_b.private_ip} priority=100 state=BACKUP

  [libresbc:vars]
  ansible_user=admin
  ansible_ssh_private_key_file=~/.ssh/stour-sbc-key.pem

  [controller]
  controller ansible_host=${aws_instance.controller.public_ip} private_ip=${aws_instance.controller.private_ip}

  [controller:vars]
  ansible_user=admin
  ansible_ssh_private_key_file=~/.ssh/stour-sbc-key.pem
  EOT
}
