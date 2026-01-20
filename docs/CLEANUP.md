# Project Cleanup Guide

## Files to Remove

```bash
# Remove duplicate backend directory
rm -rf app/database/

# Remove empty files
rm -f app/backend/config.py app/backend/models.py app/backend/wsgi.py

# Remove temporary documentation
rm -f DEPLOYMENT_FIX.md

# Remove misplaced terraform state
rm -f terraform.tfstate

# Remove site.yml (use deploy.yml instead)
rm -f ansible/site.yml
```

## Clean Generated Files

```bash
# Ansible
rm -f ansible/ansible.log ansible/ssh-key.pem
rm -f ansible/inventory/hosts.ini

# Terraform
rm -rf terraform/.terraform/
rm -f terraform/.terraform.lock.hcl terraform/tfplan
rm -f terraform/*.tfstate*

# Evidence (keep structure, remove content)
rm -f evidence/*.txt evidence/*.json
```
