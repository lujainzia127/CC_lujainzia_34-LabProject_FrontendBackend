variable "vpc_cidr_block" { type = string }
variable "subnet_cidr_block" { type = string }
variable "availability_zone" { type = string }

variable "env_prefix" {
  type        = string
  description = "Prefix used for naming/tagging resources"
}

variable "instance_type" { type = string }

variable "public_key" {
  type        = string
  description = "Path to your public key file (e.g. ~/.ssh/id_rsa.pub)"
}

variable "private_key" {
  type        = string
  description = "Path to your private key file (e.g. ~/.ssh/id_rsa)"
}
