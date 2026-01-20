# Terraform + Ansible Web Application Deployment

[![Terraform](https://img.shields.io/badge/Terraform-v1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.14+-EE0000?logo=ansible)](https://www.ansible.com/)
[![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazon-aws)](https://aws.amazon.com/ec2/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Enterprise-grade Infrastructure as Code (IaC) project demonstrating automated deployment of a web application using Terraform for provisioning and Ansible for configuration management.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Detailed Deployment](#detailed-deployment)
- [Verification](#verification)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Contributing](#contributing)

## 🎯 Overview

This project automates the complete lifecycle of a web application deployment:

1. **Infrastructure Provisioning** (Terraform)
   - EC2 instance creation
   - Security group configuration
   - SSH key pair generation
   - Network setup
   - Elastic IP allocation

2. **Configuration Management** (Ansible)
   - Nginx web server installation
   - Application deployment
   - Service management
   - Security hardening

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│           Developer Machine                  │
│  ┌──────────────┐    ┌──────────────┐       │
│  │  Terraform   │───▶│   AWS API    │       │
│  └──────────────┘    └──────────────┘       │
│         │                    │               │
│         │                    ▼               │
│         │            ┌──────────────┐        │
│         │            │  AWS Cloud   │        │
│         │            │ ┌──────────┐ │        │
│         │            │ │   VPC    │ │        │
│         │            │ │ ┌──────┐ │ │        │
│         │            │ │ │ EC2  │ │ │        │
│         │            │ │ │      │ │ │        │
│         │            │ │ └──────┘ │ │        │
│         │            │ │    │     │ │        │
│         │            │ │    │     │ │        │
│         │            │ └────┼─────┘ │        │
│         │            │      │       │        │
│         │            └──────┼───────┘        │
│         │                   │                │
│         ▼                   │                │
│  ┌──────────────┐          │                │
│  │   Ansible    │──────────┘                │
│  └──────────────┘                           │
│         │                                    │
│         ▼                                    │
│  ┌──────────────┐                           │
│  │ Nginx + App  │                           │
│  └──────────────┘                           │
└─────────────────────────────────────────────┘
```

## ✅ Prerequisites

### Required Tools

| Tool      | Minimum Version | Installation                                                                                        |
| --------- | --------------- | --------------------------------------------------------------------------------------------------- |
| Terraform | 1.5.0+          | [Install Guide](https://developer.hashicorp.com/terraform/downloads)                                |
| Ansible   | 2.14+           | [Install Guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) |
| AWS CLI   | 2.0+            | [Install Guide](https://aws.amazon.com/cli/)                                                        |
| Git       | 2.0+            | [Install Guide](https://git-scm.com/downloads)                                                      |

### AWS Configuration

1. **AWS Account**: Active AWS account with appropriate permissions
2. **IAM Permissions**: EC2, VPC, and Key Pair management
3. **AWS Credentials**: Configured via `aws configure`

```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: us-east-1
# Default output format: json
```

4. **Verify Access**:

```bash
aws sts get-caller-identity
```

## 📁 Project Structure

```
terraform-ansible-webapp/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── terraform.tfvars      # Variable values
│   └── inventory.tpl         # Ansible inventory template
├── ansible/                  # Configuration Management
│   ├── ansible.cfg           # Ansible configuration
│   ├── site.yml              # Main playbook
│   ├── inventory/            # Dynamic inventory
│   │   └── hosts.ini         # Auto-generated
│   └── roles/
│       └── webserver/        # Webserver role
│           ├── tasks/
│           │   └── main.yml
│           ├── handlers/
│           │   └── main.yml
│           └── templates/
│               ├── index.html.j2
│               └── nginx.conf.j2
├── scripts/                  # Automation scripts
│   └── deploy.sh            # Main deployment script
├── evidence/                 # Deployment evidence
│   ├── APPLY.txt
│   ├── DESTROY.txt
│   ├── curl-output.txt
│   └── EVIDENCE.md
├── screenshots/              # Verification screenshots
├── Makefile                  # Automation targets
├── .gitignore               # Git ignore rules
└── README.md                # This file
```

## 🚀 Quick Start

### Option 1: Using Makefile (Recommended)

```bash
# Clone repository
git clone <your-repo-url>
cd terraform-ansible-webapp

# Deploy everything
make all

# Open in browser
make open

# Cleanup
make destroy
```

### Option 2: Using Shell Script

```bash
# Clone repository
git clone <your-repo-url>
cd terraform-ansible-webapp

# Make script executable
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh

# Cleanup
cd terraform && terraform destroy -auto-approve | tee ../evidence/DESTROY.txt
```

## 📖 Detailed Deployment

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
terraform validate
terraform fmt
```

### Step 2: Plan Infrastructure

```bash
terraform plan -out=tfplan
terraform show tfplan
```

### Step 3: Apply Infrastructure

```bash
# Apply and save output
terraform apply tfplan | tee ../evidence/APPLY.txt

# Extract outputs
terraform output -raw public_ip
terraform output -raw ssh_private_key > ../ansible/ssh-key.pem
chmod 400 ../ansible/ssh-key.pem
```

### Step 4: Wait for EC2 Initialization

```bash
# Wait 90 seconds for EC2 to boot
sleep 90
```

### Step 5: Test Ansible Connectivity

```bash
cd ../ansible
ansible webservers -m ping -i inventory/hosts.ini
```

### Step 6: Deploy Application

```bash
ansible-playbook -i inventory/hosts.ini site.yml

# For verbose output
ansible-playbook -i inventory/hosts.ini site.yml -vv
```

### Step 7: Verify Deployment

```bash
# Get public IP
PUBLIC_IP=$(cd ../terraform && terraform output -raw public_ip)

# Test with curl
curl http://$PUBLIC_IP

# Save output
curl -v http://$PUBLIC_IP > ../evidence/curl-output.txt 2>&1

# Open in browser
xdg-open http://$PUBLIC_IP  # Linux
open http://$PUBLIC_IP       # macOS
```

## ✅ Verification

### Manual Testing

1. **Browser Test**:
   - Open `http://<PUBLIC_IP>` in your browser
   - Verify the web page loads correctly
   - Take a screenshot and save to `screenshots/`

2. **Curl Test**:

```bash
curl http://<PUBLIC_IP>
curl -I http://<PUBLIC_IP>  # Headers only
```

3. **SSH Access**:

```bash
ssh -i ansible/ssh-key.pem ec2-user@<PUBLIC_IP>
```

4. **Service Status**:

```bash
# On the EC2 instance
sudo systemctl status nginx
sudo nginx -t
```

### Expected Results

- HTTP Status: `200 OK`
- Content-Type: `text/html`
- Web page displays deployment information
- Nginx is running and enabled

## 🧹 Cleanup

### Using Makefile

```bash
make destroy
```

### Manual Cleanup

```bash
cd terraform
terraform destroy -auto-approve | tee ../evidence/DESTROY.txt

# Verify all resources are deleted
aws ec2 describe-instances --filters "Name=tag:Project,Values=terraform-ansible-webapp"
```

### Clean Generated Files

```bash
make clean
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Terraform Init Fails

**Problem**: Provider download errors

**Solution**:

```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### 2. Ansible Connection Timeout

**Problem**: Cannot connect to EC2 instance

**Solution**:

```bash
# Wait longer for EC2 to initialize
sleep 120

# Check security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids <sg-id>

# Test SSH manually
ssh -i ansible/ssh-key.pem ec2-user@<PUBLIC_IP>
```

#### 3. Permission Denied for SSH Key

**Problem**: SSH key permissions too open

**Solution**:

```bash
chmod 400 ansible/ssh-key.pem
```

#### 4. Nginx Installation Fails

**Problem**: Package not found

**Solution**:

```bash
# Verify instance can reach internet
ssh -i ansible/ssh-key.pem ec2-user@<PUBLIC_IP>
ping -c 3 8.8.8.8

# Update package cache
sudo yum update -y
```

#### 5. HTTP Request Returns 403 or 404

**Problem**: Web page not accessible

**Solution**:

```bash
# Check Nginx status
ssh -i ansible/ssh-key.pem ec2-user@<PUBLIC_IP>
sudo systemctl status nginx
sudo nginx -t

# Check file permissions
sudo ls -la /usr/share/nginx/html/

# Check firewall
sudo iptables -L -n
```

### Debug Mode

**Terraform**:

```bash
export TF_LOG=DEBUG
terraform apply
```

**Ansible**:

```bash
ansible-playbook -i inventory/hosts.ini site.yml -vvv
```

## 📚 Best Practices

### Security

1. **SSH Key Management**
   - Never commit private keys to Git
   - Use key pairs with 4096-bit encryption
   - Rotate keys regularly

2. **Security Groups**
   - Restrict SSH access to your IP: `ssh_allowed_ips = ["YOUR_IP/32"]`
   - Use HTTPS in production
   - Enable AWS security services

3. **Secrets Management**
   - Use AWS Secrets Manager for sensitive data
   - Never hardcode credentials
   - Use environment variables

### Cost Optimization

1. **Instance Types**
   - Use `t2.micro` for free tier
   - Stop instances when not in use
   - Use Elastic IPs cautiously

2. **Resource Cleanup**
   - Always run `terraform destroy` after testing
   - Monitor AWS Cost Explorer
   - Set up billing alerts

### Code Quality

1. **Terraform**
   - Run `terraform fmt` before committing
   - Use `terraform validate` to check syntax
   - Add comments to complex resources

2. **Ansible**
   - Use roles for modularity
   - Implement handlers for service management
   - Test playbooks with `--check` mode

3. **Version Control**
   - Use meaningful commit messages
   - Tag releases
   - Document changes

## 📦 Deliverables Checklist

- [ ] Terraform files (`main.tf`, `variables.tf`, `outputs.tf`)
- [ ] Ansible files (`ansible.cfg`, `site.yml`, roles)
- [ ] `evidence/APPLY.txt` - Terraform apply output
- [ ] `evidence/DESTROY.txt` - Terraform destroy output
- [ ] `evidence/curl-output.txt` - HTTP verification
- [ ] `screenshots/webpage-browser.png` - Browser screenshot
- [ ] `README.md` - Complete documentation
- [ ] GitHub repository with all code

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS Documentation](https://docs.aws.amazon.com/)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/terraform-ansible-webapp/issues)
- **Email**: your.email@example.com
- **Documentation**: [Project Wiki](https://github.com/yourusername/terraform-ansible-webapp/wiki)

---

**Made with ❤️ using Infrastructure as Code**

_Last Updated: January 2026_
