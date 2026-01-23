# Terraform + Ansible Web Application Deployment

Automated deployment of a web application using Terraform for AWS infrastructure provisioning and Ansible for configuration management.

## Prerequisites

- Terraform 1.5.0+
- Ansible 2.14+
- AWS CLI configured with credentials
- AWS account with EC2 permissions

## Project Structure

```
terraform-ansible-webapp/
├── terraform/          # Infrastructure provisioning
├── ansible/            # Configuration management
├── scripts/            # Deployment scripts
└── evidence/           # Deployment outputs
```

## Quick Start

```bash
# Deploy
make all

# Cleanup
make destroy
```

## Manual Deployment

```bash
cd terraform
terraform init
terraform apply -auto-approve | tee ../evidence/APPLY.txt
sleep 90

cd ../ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

## Verification

```bash
# Get public IP
PUBLIC_IP=$(cd terraform && terraform output -raw public_ip)

# Test
curl http://$PUBLIC_IP
```

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve | tee ../evidence/DESTROY.txt
```


