# HOW TO RUN THIS PROJECT

## 📋 Overview

This is a **Terraform + Ansible Infrastructure-as-Code project** that deploys a full-stack web application (Flask backend + React frontend) to AWS EC2 with security hardening and compliance monitoring.

---

## 🔧 PREREQUISITES

### System Requirements

- **Terraform** v1.5.0+ ([install](https://developer.hashicorp.com/terraform/downloads))
- **Ansible** 2.12+ ([install](https://docs.ansible.com/ansible/latest/installation_guide/))
- **AWS Account** with credentials configured
- **Python** 3.8+ for backend/local tools
- **Node.js** 18+ for frontend (optional, handled by Ansible)
- **SSH key pair** for EC2 access

### AWS Setup

```bash
# Install AWS CLI
brew install awscli

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)

# Verify access
aws sts get-caller-identity
```

### Local Python Environment

```bash
# Navigate to project
cd /Users/huey/Desktop/Amalitech/terraform-ansible-webapp

# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Install Python dependencies
pip install -r ansible/requirements.txt 2>/dev/null || pip install ansible terraform pre-commit
```

---

## 🚀 QUICK START (5-10 minutes)

### Step 1: Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads AWS provider)
terraform init

# Validate configuration
terraform validate

# See what will be created
terraform plan
```

### Step 2: Deploy Infrastructure

```bash
# Create AWS resources (EC2, security groups, etc.)
terraform apply

# When prompted, type: yes
# ⏱️ Wait ~2 minutes for completion

# View outputs (public IP, instance details and helper commands)
terraform output
```

**Key outputs**:

- `public_ip` - Your EC2 instance's public IP
- `deployment_summary` - Grouped view of instance_id, public_ip, web_url, region, AZ
- `webapp_url` - Direct URL to the deployed app

### Step 3: Configure Ansible Inventory

```bash
cd ../ansible

# Get the public IP from terraform output
export INSTANCE_IP=$(cd ../terraform && terraform output -raw public_ip)

# Create inventory file
cat > inventory/hosts.ini <<EOF
[webservers]
webapp ansible_host=$INSTANCE_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/webapp-key.pem
EOF

# Verify connectivity
ansible all -i inventory/hosts.ini -m ping
```

### Step 4: Deploy Application with Ansible

```bash
# Run the deployment playbook
ansible-playbook -i inventory/hosts.ini deploy.yml

# Wait for completion (~3-5 minutes)
# ✅ You'll see green [ok] messages when tasks succeed
```

### Step 5: Access Your Application

```bash
# Get your public IP
INSTANCE_IP=$(cd ../terraform && terraform output -raw public_ip)

# Open in browser
# Frontend: http://$INSTANCE_IP
# Backend API: http://$INSTANCE_IP:5000/api/health

# Or via curl
curl http://$INSTANCE_IP
curl http://$INSTANCE_IP:5000/api/health
```

---

## 📁 PROJECT STRUCTURE

```
terraform-ansible-webapp/
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                         # EC2, security groups, networking
│   ├── variables.tf                    # Input variables (customizable)
│   ├── outputs.tf                      # Export instance details and helper commands
│   ├── terraform.tfvars.example        # Example variable values (copy to terraform.tfvars)
│   └── terraform.tfstate               # State file (don't edit manually, path shown for reference)
│
├── ansible/                            # Configuration Management
│   ├── deploy.yml                      # Main playbook
│   ├── monitoring-playbook.yml         # Audit logging & compliance
│   ├── ansible.cfg                     # Ansible configuration
│   ├── .ansible-lint                   # Linting rules
│   ├── inventory/
│   │   └── hosts.ini                   # Target hosts (generated after terraform)
│   ├── roles/
│   │   └── webserver/
│   │       ├── tasks/main.yml          # What to install/configure
│   │       ├── handlers/main.yml       # Service restart handlers
│   │       ├── templates/              # Nginx, backend service configs
│   │       └── files/
│   │           └── threat-detection.sh # Security monitoring script
│   └── policies/
│       └── ansible_security.rego       # OPA/Rego security policies
│
├── app/                                # Application Code
│   ├── backend/
│   │   ├── app.py                      # Flask API server
│   │   ├── requirements.txt            # Python dependencies
│   │   └── .env.example                # Environment variables template
│   └── frontend/
│       ├── package.json                # Node.js dependencies
│       ├── src/
│       │   ├── App.js                  # React component
│       │   └── App.css                 # Styling
│       └── public/
│           └── index.html              # HTML entry point
│
├── .pre-commit-config.yaml             # Git pre-commit hooks
├── .gitleaks.toml                      # Secret detection config
└── ANSIBLE_OVERVIEW.md                 # High-level explanation of Ansible in this project
```

---

## 🎯 DETAILED STEP-BY-STEP GUIDE

### Phase 1: Infrastructure Setup (Terraform)

#### 1.1 Customize Variables

```bash
cd terraform

# Edit terraform.tfvars to customize deployment
nano terraform.tfvars

# Key variables:
# - aws_region: AWS region (default: us-east-1)
# - instance_type: EC2 instance size (default: t2.micro)
# - ssh_allowed_ips: Your IP (restrict SSH access)
```

#### 1.2 Initialize & Plan

```bash
# Download AWS provider plugins
terraform init

# Validate syntax
terraform validate

# Preview changes (doesn't apply anything)
terraform plan > tfplan.txt
cat tfplan.txt
```

#### 1.3 Apply Infrastructure

```bash
# Create actual AWS resources
terraform apply -auto-approve

# Or review first:
terraform apply
# Type: yes when prompted

# Save outputs for ansible
terraform output > ../terraform_outputs.txt
```

#### 1.4 Verify AWS Resources

```bash
# List created instances
aws ec2 describe-instances --query 'Reservations[].Instances[].{IP:PublicIpAddress,ID:InstanceId,State:State.Name}'

# Check security groups
aws ec2 describe-security-groups --query 'SecurityGroups[].{Name:GroupName,ID:GroupId,Ingress:IpPermissions}'
```

---

### Phase 2: Ansible Deployment

#### 2.1 Prepare Inventory

```bash
cd ../ansible

# Option A: Generate from Terraform output
export INSTANCE_IP=$(cd ../terraform && terraform output -raw public_ip)
export INSTANCE_ID=$(cd ../terraform && terraform output -raw instance_id)

# Option B: Create manually
cat > inventory/hosts.ini <<'EOF'
[webservers]
webapp ansible_host=YOUR_PUBLIC_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/webapp-key.pem

[webservers:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
```

#### 2.2 Test SSH Connectivity

```bash
# Verify Ansible can reach the instance
ansible all -i inventory/hosts.ini -m ping

# You should see:
# webapp | SUCCESS => {
#    "ping": "pong"
# }
```

#### 2.3 Run Deployment Playbook

```bash
# Full deployment (30-60 seconds)
ansible-playbook -i inventory/hosts.ini deploy.yml -v

# Watch for [ok] = success, [changed] = modified, [failed] = error
```

#### 2.4 Verify Deployment

```bash
# Check if services are running
ansible all -i inventory/hosts.ini -m shell -a "systemctl status nginx taskmanager-backend" | grep active

# View logs
ansible all -i inventory/hosts.ini -m shell -a "tail -20 /var/log/nginx/access.log"
```

---

### Phase 3: Test the Application

#### 3.1 Access Frontend

```bash
# Get public IP
INSTANCE_IP=$(cd terraform && terraform output -raw public_ip)

# Open in browser
open http://$INSTANCE_IP

# Or curl it
curl -I http://$INSTANCE_IP
# Should see: HTTP/1.1 200 OK
```

#### 3.2 Test Backend API

```bash
# Health check endpoint
curl http://$INSTANCE_IP:5000/api/health

# Expected response (JSON)
# {"status": "healthy", "timestamp": "2026-01-27T..."}

# View backend logs
ansible all -i inventory/hosts.ini -m shell -a "tail -20 /var/log/webapp/app.log"
```

#### 3.3 Test Security Headers

```bash
# Check that security headers are set
curl -I http://$INSTANCE_IP | grep -E "X-Content-Type-Options|X-Frame-Options|Strict-Transport-Security"

# Expected headers:
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
# Strict-Transport-Security: max-age=31536000
```

---

## 🔒 OPTIONAL: Security Enhancements

### Enable Pre-Commit Hooks (Local)

```bash
# Install dependencies
pip install pre-commit ansible-lint yamllint

# Install git hooks
pre-commit install

# Test hooks
pre-commit run --all-files

# Now hooks run automatically before each commit
```

### Deploy Audit Logging

```bash
# Configure system audit and compliance monitoring
ansible-playbook -i inventory/hosts.ini monitoring-playbook.yml

# Verify logs are collected
ansible all -i inventory/hosts.ini -m shell -a "ls -la /var/log/audit/"
```

### Enable Threat Detection

```bash
# Deploy threat monitoring script
ansible all -i inventory/hosts.ini -m copy -a "src=roles/webserver/files/threat-detection.sh dest=/opt/monitoring/threat-detection.sh mode=0755" -b

# Schedule cron job
ansible all -i inventory/hosts.ini -m cron -a "name='threat-detection' minute='*/5' job='/opt/monitoring/threat-detection.sh'" -b

# Monitor alerts
ansible all -i inventory/hosts.ini -m shell -a "tail -f /var/log/webapp/threats.log" -b
```

---

## 🧹 CLEANUP & DESTROY

### Destroy AWS Resources (Free Up Costs)

```bash
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Actually destroy
terraform destroy

# When prompted, type: yes

# Verify deletion
aws ec2 describe-instances --query 'Reservations[].Instances[].State.Name' | grep -i terminated
```

### Cleanup Local State

```bash
# Remove terraform state files
rm -f terraform.tfstate* .terraform.lock.hcl

# Remove cached files
rm -rf .terraform/

# Remove ansible cache
rm -rf .ansible/
```

---

## 📊 MONITORING & LOGS

### View Application Logs

```bash
# Backend Flask logs
ansible all -i inventory/hosts.ini -m shell -a "tail -50 /var/log/webapp/app.log" -b

# Nginx access logs
ansible all -i inventory/hosts.ini -m shell -a "tail -50 /var/log/nginx/access.log" -b

# Nginx error logs
ansible all -i inventory/hosts.ini -m shell -a "tail -50 /var/log/nginx/error.log" -b
```

### Check System Health

```bash
# CPU & memory usage
ansible all -i inventory/hosts.ini -m shell -a "top -bn1 | head -20" -b

# Disk usage
ansible all -i inventory/hosts.ini -m shell -a "df -h" -b

# Open ports
ansible all -i inventory/hosts.ini -m shell -a "ss -tlnp" -b
```

### Security Checks

```bash
# View firewall rules
ansible all -i inventory/hosts.ini -m shell -a "firewall-cmd --list-all" -b

# Check SELinux status
ansible all -i inventory/hosts.ini -m shell -a "getenforce" -b

# View SSH config
ansible all -i inventory/hosts.ini -m shell -a "grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config" -b
```

---

## 🐛 TROUBLESHOOTING

### Issue: Terraform Init Fails

```bash
# Solution: Check AWS credentials
aws sts get-caller-identity

# If fails, reconfigure:
aws configure
```

### Issue: Ansible Can't Connect

```bash
# Check SSH key permissions
ls -la ~/.ssh/webapp-key.pem
chmod 600 ~/.ssh/webapp-key.pem

# Test SSH directly
ssh -i ~/.ssh/webapp-key.pem ec2-user@YOUR_IP

# If still fails, check security group
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

### Issue: Application Not Responding

```bash
# Check if services are running
ansible all -i inventory/hosts.ini -m shell -a "systemctl status nginx taskmanager-backend" -b

# View error logs
ansible all -i inventory/hosts.ini -m shell -a "journalctl -u taskmanager-backend -n 50" -b

# Check port 80/443/5000
ansible all -i inventory/hosts.ini -m shell -a "netstat -tlnp | grep LISTEN" -b
```

### Issue: Ansible Playbook Fails

```bash
# Run with verbose output
ansible-playbook -i inventory/hosts.ini deploy.yml -vvv

# Check for syntax errors
ansible-playbook --syntax-check deploy.yml

# Run specific role
ansible-playbook -i inventory/hosts.ini deploy.yml --tags webserver
```

---

## 📈 COMMON TASKS

### Update Application Code

```bash
# Edit app files locally
nano app/backend/app.py
nano app/frontend/src/App.js

# Re-deploy with Ansible
ansible-playbook -i inventory/hosts.ini deploy.yml --tags app
```

### Scale Up Instance

```bash
# Edit variables
nano terraform/terraform.tfvars

# Change instance_type to larger (t2.small, t2.medium, etc.)

# Plan and apply
cd terraform
terraform plan
terraform apply
```

### Add Custom Configuration

```bash
# Edit Ansible role
nano ansible/roles/webserver/tasks/main.yml

# Add custom templates
cp myconfig.j2 ansible/roles/webserver/templates/

# Re-deploy
ansible-playbook -i inventory/hosts.ini deploy.yml
```

### Backup Application State

````bash
# Export SQLite task database from the server
ansible all -i inventory/hosts.ini -m shell -a "cp /opt/taskmanager/backend/tasks.db /tmp/tasks-backup.db" -b

# Download to local machine
ansible all -i inventory/hosts.ini -m fetch -a "src=/tmp/tasks-backup.db dest=./backups/ flat=yes" -b

### Access the Task Database (SQLite)

The backend uses a local **SQLite** database stored on the EC2 instance.

- **Database file path on the server**: `/opt/taskmanager/backend/tasks.db`

To inspect or query the database:

```bash
# 1) Get the SSH command Terraform generated for you
cd terraform
terraform output -raw ssh_command
# Copy and run the printed ssh command, for example:
# ssh -i /absolute/path/to/key.pem ec2-user@YOUR_PUBLIC_IP

# 2) On the EC2 instance, open the SQLite database
cd /opt/taskmanager/backend
sqlite3 tasks.db

# Inside the sqlite3 shell:
.tables          -- list tables (Task, Category, etc.)
PRAGMA table_info('Task');
SELECT * FROM Task LIMIT 5;

# Exit sqlite3
.quit
````

To copy the raw database file to your local machine without Ansible you can also:

```bash
# From your local machine (after getting PUBLIC_IP and key path from terraform output)
scp -i /absolute/path/to/key.pem ec2-user@PUBLIC_IP:/opt/taskmanager/backend/tasks.db ./tasks.db
```

```

---

## 🔐 Security Best Practices

### ✅ DO's
- [x] Restrict SSH access to your IP in `terraform.tfvars`
- [x] Use Ansible Vault for sensitive data
- [x] Enable audit logging with monitoring-playbook.yml
- [x] Run pre-commit hooks before pushing
- [x] Keep SSH keys secure (chmod 600)

### ❌ DON'Ts
- [ ] Don't expose database credentials in code
- [ ] Don't commit `.tfstate` files to Git
- [ ] Don't use root user for deployments
- [ ] Don't disable SSH key authentication
- [ ] Don't leave firewall open to 0.0.0.0/0

---

## 📚 ADDITIONAL RESOURCES

### Documentation Files
- `ANSIBLE_SECURITY_AUDIT.md` - Security analysis
- `MOLECULE_TESTING_FRAMEWORK.md` - Automated testing setup
- `SHIFT_LEFT_SECURITY_POLICY_ENFORCEMENT.md` - Pre-deployment checks
- `SECURITY_MONITORING_COMPLIANCE_FRAMEWORK.md` - Post-deployment compliance

### External Links
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Flask Security Best Practices](https://flask.palletsprojects.com/security/)
- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)

---

## ✅ VERIFICATION CHECKLIST

After deployment, verify:

- [ ] Terraform apply completed successfully
- [ ] Ansible ping returns SUCCESS
- [ ] Frontend loads (HTTP 200)
- [ ] Backend health check responds
- [ ] Security headers present
- [ ] Nginx running and reachable
- [ ] Backend service running
- [ ] Logs being collected
- [ ] Firewall rules restricting SSH
- [ ] SSH key authentication only (no passwords)

---

**Last Updated**: 2026-01-27
**Project Status**: Production Ready
**Estimated Time**: 15-30 minutes for full deployment
```
