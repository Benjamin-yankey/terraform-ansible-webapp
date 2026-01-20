#!/bin/bash

###############################################################################
# Project Setup Script
# Description: Creates complete project structure and files
# Author: DevOps Team
# Version: 1.0.0
###############################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="terraform-ansible-webapp"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Setting up Terraform + Ansible Web App Project        ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"

mkdir -p "$PROJECT_ROOT"/{terraform,ansible/{roles/webserver/{tasks,handlers,templates,files},inventory},evidence,screenshots,scripts}

echo -e "${GREEN}✓ Directory structure created${NC}"

# Create Terraform files
echo -e "${YELLOW}Creating Terraform configuration files...${NC}"

cat > "$PROJECT_ROOT/terraform/main.tf" << 'EOF'
# See the provided main.tf content
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
EOF

cat > "$PROJECT_ROOT/terraform/variables.tf" << 'EOF'
# See the provided variables.tf content
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}
EOF

cat > "$PROJECT_ROOT/terraform/outputs.tf" << 'EOF'
# See the provided outputs.tf content
output "public_ip" {
  description = "Public IP address"
  value       = aws_eip.webapp_eip.public_ip
}
EOF

cat > "$PROJECT_ROOT/terraform/terraform.tfvars" << 'EOF'
aws_region = "us-east-1"
project_name = "terraform-ansible-webapp"
environment = "dev"
owner = "Your Name"
instance_type = "t2.micro"
root_volume_size = 8
enable_monitoring = true
ssh_allowed_ips = ["0.0.0.0/0"]
EOF

echo -e "${GREEN}✓ Terraform files created${NC}"

# Create Ansible files
echo -e "${YELLOW}Creating Ansible configuration files...${NC}"

cat > "$PROJECT_ROOT/ansible/ansible.cfg" << 'EOF'
[defaults]
inventory = ./inventory/hosts.ini
host_key_checking = False
remote_user = ec2-user
timeout = 30
stdout_callback = yaml
log_path = ./ansible.log
become = True
become_method = sudo
roles_path = ./roles
EOF

cat > "$PROJECT_ROOT/ansible/site.yml" << 'EOF'
---
- name: Deploy Web Application
  hosts: webservers
  become: yes
  gather_facts: yes
  roles:
    - webserver
EOF

echo -e "${GREEN}✓ Ansible files created${NC}"

# Create automation files
echo -e "${YELLOW}Creating automation scripts...${NC}"

cat > "$PROJECT_ROOT/Makefile" << 'EOF'
.PHONY: all help
all: init plan apply wait deploy verify
help:
	@echo "Available targets: all, init, plan, apply, deploy, verify, destroy, clean"
EOF

cat > "$PROJECT_ROOT/.gitignore" << 'EOF'
.terraform/
*.tfstate*
*.pem
*.key
ssh-key*
ansible/inventory/hosts.ini
evidence/APPLY.txt
evidence/DESTROY.txt
*.log
.DS_Store
EOF

echo -e "${GREEN}✓ Automation files created${NC}"

# Create README
echo -e "${YELLOW}Creating documentation...${NC}"

cat > "$PROJECT_ROOT/README.md" << 'EOF'
# Terraform + Ansible Web Application

Infrastructure as Code project for automated web server deployment.

## Quick Start
1. Configure AWS credentials: `aws configure`
2. Update `terraform/terraform.tfvars` with your details
3. Run deployment: `make all` or `./scripts/deploy.sh`
4. Access web app at the provided URL
5. Cleanup: `make destroy`

## Documentation
See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for detailed steps.
EOF

echo -e "${GREEN}✓ Documentation created${NC}"

# Make scripts executable
chmod +x "$PROJECT_ROOT"/scripts/*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ✓ Project setup complete!                             ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. cd $PROJECT_ROOT"
echo "  2. Update terraform/terraform.tfvars with your AWS details"
echo "  3. Run: make all  (or ./scripts/deploy.sh)"
echo ""
echo -e "${YELLOW}Note: You'll need to copy the full file contents from the artifact${NC}"
echo -e "${YELLOW}      This script created the directory structure only.${NC}"
echo ""