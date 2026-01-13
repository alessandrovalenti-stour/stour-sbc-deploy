provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

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

  # SSH (temporary: 0.0.0.0/0 as per your choice)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sbc-sg"
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

  tags = {
    Name        = "${var.project}-sbc-a"
    Role        = "libresbc"
    Node        = "A"
    AZ          = "eu-west-2a"
    Environment = "non-production"
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

  tags = {
    Name        = "${var.project}-sbc-b"
    Role        = "libresbc"
    Node        = "B"
    AZ          = "eu-west-2b"
    Environment = "non-production"
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
  EOT
}
