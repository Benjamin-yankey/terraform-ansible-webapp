terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      Application = "TaskManager"
    }
  }
}

# Data source to get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Generate SSH key pair
resource "tls_private_key" "webapp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "webapp_key" {
  key_name   = "${var.project_name}-key-${var.environment}"
  public_key = tls_private_key.webapp_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-keypair"
  }
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.webapp_key.private_key_pem
  filename        = "${path.module}/../ansible/ssh-key.pem"
  file_permission = "0400"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group for Full-Stack Application
resource "aws_security_group" "webapp_sg" {
  name        = "${var.project_name}-sg-${var.environment}"
  description = "Security group for ${var.project_name} full-stack application"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_ips
  }

  # HTTP access (Frontend)
  ingress {
    description = "HTTP for Frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API port (Flask)
  ingress {
    description = "Backend API"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-security-group"
  }
}

# EC2 Instance with increased resources for full-stack app
resource "aws_instance" "webapp" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.webapp_key.key_name
  vpc_security_group_ids = [aws_security_group.webapp_sg.id]

  # User data for full-stack setup
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              yum update -y
              
              # Install development tools
              yum groupinstall -y "Development Tools"
              
              # Install Python3 and dependencies
              yum install -y python3 python3-pip python3-devel
              
              # Install Git
              yum install -y git
              
              # Create application directory
              mkdir -p /opt/taskmanager
              chown ec2-user:ec2-user /opt/taskmanager
              
              # Create marker file
              touch /tmp/cloud-init-complete
              
              # Log completion
              echo "User data script completed at $(date)" >> /var/log/user-data.log
              EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring = var.enable_monitoring

  tags = {
    Name        = "${var.project_name}-instance"
    Application = "TaskManager-FullStack"
    Backend     = "Flask-Python"
    Frontend    = "React"
  }

  # Wait for instance to be ready
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

# Elastic IP
resource "aws_eip" "webapp_eip" {
  instance = aws_instance.webapp.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_instance.webapp]
}

# Create Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    public_ip   = aws_eip.webapp_eip.public_ip
    private_key = "${path.module}/../ansible/ssh-key.pem"
    ssh_user    = "ec2-user"
  })
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"

  depends_on = [aws_eip.webapp_eip, local_file.private_key]
}

# Output for deployment script
resource "local_file" "deployment_vars" {
  content = jsonencode({
    public_ip        = aws_eip.webapp_eip.public_ip
    frontend_url     = "http://${aws_eip.webapp_eip.public_ip}"
    backend_api_url  = "http://${aws_eip.webapp_eip.public_ip}:5000/api"
    health_check_url = "http://${aws_eip.webapp_eip.public_ip}:5000/api/health"
    instance_id      = aws_instance.webapp.id
  })
  filename        = "${path.module}/../evidence/deployment_vars.json"
  file_permission = "0644"

  depends_on = [aws_eip.webapp_eip]
}
