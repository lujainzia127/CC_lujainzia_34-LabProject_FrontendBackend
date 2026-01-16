provider "aws" {
  # derive region from AZ (e.g. us-east-1a -> us-east-1)
  region = substr(var.availability_zone, 0, length(var.availability_zone) - 1)
}

# --- Networking (module) ---
module "subnet" {
  source            = "./modules/subnet"
  vpc_cidr_block    = var.vpc_cidr_block
  subnet_cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  env_prefix        = var.env_prefix
}

# --- Security Group ---
resource "aws_security_group" "web" {
  name        = "${var.env_prefix}-web-sg"
  description = "SSH from my IP; HTTP from anywhere"
  vpc_id      = module.subnet.vpc_id

  ingress {
    description = "SSH from Codespace IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.env_prefix}-web-sg" }
}

# --- Key Pair ---
resource "aws_key_pair" "lab" {
  key_name   = "${var.env_prefix}-key"
  public_key = file(var.public_key)
}

# --- AMI (Amazon Linux 2) ---
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- EC2 Instances ---
resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type
  subnet_id                   = module.subnet.subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.env_prefix}-frontend"
    Role = "frontend"
  }
}

resource "aws_instance" "backend" {
  count                       = 3
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type
  subnet_id                   = module.subnet.subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.env_prefix}-backend-${count.index + 1}"
    Role = "backend"
  }
}

# --- Generate Ansible inventory from template ---
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory/hosts"
  content = templatefile("${path.module}/ansible/inventory/hosts.tpl", {
    frontend_public_ip  = aws_instance.frontend.public_ip
    backend_public_ips  = [for b in aws_instance.backend : b.public_ip]
    backend_private_ips = [for b in aws_instance.backend : b.private_ip]
    private_key_path    = var.private_key
  })
}

# --- Trigger Ansible automatically after infra ---
resource "null_resource" "configure_with_ansible" {
  triggers = {
    frontend_ip = aws_instance.frontend.public_ip
    backends    = join(",", [for b in aws_instance.backend : b.public_ip])
  }

  depends_on = [
    aws_instance.frontend,
    aws_instance.backend,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Waiting 60s for EC2 SSH readiness..."
      sleep 60
      cd ansible
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts playbooks/site.yaml
    EOT
  }
}
