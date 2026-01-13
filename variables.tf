variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "project" {
  type    = string
  default = "stour-libresbc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ssh_key_name" {
  description = "Existing EC2 KeyPair name"
  type        = string
}

variable "admin_cidr" {
  description = "Your public IP /32 for SSH access"
  type        = string
}

variable "rtp_port_min" {
  type    = number
  default = 10000
}

variable "rtp_port_max" {
  type    = number
  default = 20000
}

variable "enable_sip_tls" {
  type    = bool
  default = false
}

variable "existing_vpc_id" {
  type        = string
  description = "Existing VPC ID (non-production)"
}

variable "subnet_a_id" {
  type        = string
  description = "Public subnet ID in eu-west-2a"
}

variable "subnet_b_id" {
  type        = string
  description = "Public subnet ID in eu-west-2b"
}
