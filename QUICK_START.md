# 🚀 QUICK START COMMANDS

Copy-paste ready commands to deploy your project in 5 minutes.

## Prerequisites (One-time Setup)

```bash
# Install Terraform
brew install terraform

# Install Ansible
brew install ansible

# Configure AWS
aws configure
# Enter your AWS Access Key ID, Secret, and Region

# Navigate to project
cd /Users/huey/Desktop/Amalitech/terraform-ansible-webapp
```

---

## PHASE 1: Deploy Infrastructure (2 minutes)

```bash
# Go to terraform directory
cd terraform

# Initialize terraform
terraform init

# Create AWS resources
terraform apply -auto-approve

# Get your instance IP
terraform output -raw instance_public_ip > /tmp/instance_ip.txt
cat /tmp/instance_ip.txt
```

---

## PHASE 2: Deploy Application (3 minutes)

```bash
# Go back to root
cd ../

# Get instance IP
INSTANCE_IP=$(cat /tmp/instance_ip.txt)

# Create inventory file
cat > ansible/inventory/hosts.ini <<EOF
[webservers]
webapp ansible_host=$INSTANCE_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/webapp-key.pem
EOF

# Change to ansible directory
cd ansible

# Test connectivity
ansible all -i inventory/hosts.ini -m ping

# Deploy application
ansible-playbook -i inventory/hosts.ini deploy.yml
```

---

## PHASE 3: Test Application (1 minute)

```bash
# Get your public IP
INSTANCE_IP=$(cat /tmp/instance_ip.txt)

# Test frontend
echo "Frontend URL: http://$INSTANCE_IP"
curl -I http://$INSTANCE_IP

# Test backend
echo "Backend API: http://$INSTANCE_IP:5000/api/health"
curl http://$INSTANCE_IP:5000/api/health

# Open in browser
open http://$INSTANCE_IP
```

---

## CLEANUP: Destroy Everything (1 minute)

```bash
# Go to terraform
cd terraform

# Destroy AWS resources (careful!)
terraform destroy -auto-approve

# Verify deletion
aws ec2 describe-instances --query 'Reservations[].Instances[].State.Name'
```

---

## Common Issues & Fixes

### Can't connect with Ansible?
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/webapp-key.pem

# Test SSH manually
ssh -i ~/.ssh/webapp-key.pem ec2-user@$INSTANCE_IP

# Check security group
aws ec2 describe-security-groups --query 'SecurityGroups[0].IpPermissions'
```

### Application not responding?
```bash
# Check if services are running
ansible all -i inventory/hosts.ini -m shell -a "systemctl status nginx backend" -b

# View logs
ansible all -i inventory/hosts.ini -m shell -a "tail -20 /var/log/nginx/error.log" -b
```

### Terraform apply failed?
```bash
# Check AWS credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure

# Try again
terraform apply -auto-approve
```

---

## Full Deployment Script (Save as `deploy.sh`)

```bash
#!/bin/bash
set -e

echo "🚀 Starting deployment..."

# Phase 1: Terraform
echo "📦 Creating AWS infrastructure..."
cd terraform
terraform init
terraform apply -auto-approve
INSTANCE_IP=$(terraform output -raw instance_public_ip)
cd ..

# Phase 2: Ansible
echo "⚙️  Configuring application..."
cat > ansible/inventory/hosts.ini <<EOF
[webservers]
webapp ansible_host=$INSTANCE_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/webapp-key.pem
EOF

cd ansible
ansible all -i inventory/hosts.ini -m ping
ansible-playbook -i inventory/hosts.ini deploy.yml
cd ..

# Phase 3: Verification
echo "✅ Deployment complete!"
echo ""
echo "Frontend: http://$INSTANCE_IP"
echo "Backend:  http://$INSTANCE_IP:5000/api/health"
echo ""
echo "To access:"
echo "  open http://$INSTANCE_IP"
echo ""
echo "To destroy:"
echo "  cd terraform && terraform destroy -auto-approve"
```

Save and run:
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## Environment Variables (Optional)

```bash
# Set these to avoid editing files
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export INSTANCE_IP=$(terraform output -raw instance_public_ip)
export SSH_KEY_PATH=~/.ssh/webapp-key.pem
export INSTANCE_USER=ec2-user
```

---

**Time Estimate**: 5-10 minutes from start to working application
**Cost Estimate**: ~$0.50/day for t2.micro (eligible for AWS free tier)
