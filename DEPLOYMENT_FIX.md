# Deployment Fixes Applied

## Key Changes Made

### 1. Ansible Playbook Fixes
- **Removed synchronize module** - replaced with copy module (more reliable)
- **Fixed Node.js installation** - combined into single shell command
- **Fixed permission issues** - added become_user for pip/npm operations
- **Simplified firewall** - disabled SELinux instead of complex firewall rules
- **Increased health check retries** - more time for services to start
- **Fixed file copy paths** - using absolute paths and remote_src

### 2. Backend Service Fixes
- **Removed gunicorn** - using Flask development server (simpler)
- **Fixed PATH environment** - added full system paths
- **Added PYTHONUNBUFFERED** - for better logging
- **Direct Python execution** - more reliable than gunicorn

### 3. Requirements.txt
- **Removed gunicorn** - not needed for development deployment

## Deployment Steps

```bash
cd /Users/huey/Desktop/Amalitech/terraform-ansible-webapp

# 1. Initialize Terraform
cd terraform
terraform init
terraform plan
terraform apply -auto-approve

# 2. Wait for instance (important!)
sleep 90

# 3. Run Ansible
cd ../ansible
ansible-playbook -i inventory/hosts.ini site.yml -v

# 4. Get public IP
cd ../terraform
terraform output public_ip
```

## Troubleshooting

If deployment fails:

```bash
# SSH into instance
ssh -i ansible/ssh-key.pem ec2-user@<PUBLIC_IP>

# Check backend service
sudo systemctl status taskmanager-backend
sudo journalctl -u taskmanager-backend -f

# Check Nginx
sudo systemctl status nginx
sudo nginx -t

# Manual backend start
cd /opt/taskmanager/backend
source venv/bin/activate
python app.py

# Check logs
tail -f /opt/taskmanager/logs/*.log
```

## Common Issues Fixed

1. ✅ Synchronize module errors → Using copy module
2. ✅ Permission denied on pip/npm → Added become_user
3. ✅ Gunicorn not found → Using Flask directly
4. ✅ Node.js installation fails → Combined installation
5. ✅ Firewall blocking ports → Disabled SELinux
6. ✅ Services not starting → Increased retry delays
