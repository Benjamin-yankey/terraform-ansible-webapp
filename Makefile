.PHONY: help init plan apply deploy destroy clean health backup ssh

help:
	@echo "Available commands:"
	@echo "  make init      - Initialize Terraform"
	@echo "  make plan      - Plan infrastructure changes"
	@echo "  make apply     - Apply infrastructure changes"
	@echo "  make deploy    - Deploy application with Ansible"
	@echo "  make all       - Full deployment (init + apply + deploy)"
	@echo "  make health    - Check application health"
	@echo "  make backup    - Backup database"
	@echo "  make ssh       - SSH into EC2 instance"
	@echo "  make destroy   - Destroy infrastructure"
	@echo "  make clean     - Clean generated files"

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply -auto-approve | tee evidence/APPLY.txt

deploy:
	cd ansible && ansible-playbook -i inventory/hosts.ini deploy.yml

all: init apply
	@sleep 60
	@$(MAKE) deploy

health:
	@./scripts/health-check.sh

backup:
	@./scripts/backup-db.sh

ssh:
	@IP=$$(cd terraform && terraform output -raw public_ip 2>/dev/null || cat ../evidence/public_ip.txt); \
	ssh -i ansible/ssh-key.pem ec2-user@$$IP

destroy:
	cd terraform && terraform destroy -auto-approve | tee evidence/DESTROY.txt

clean:
	rm -rf terraform/.terraform terraform/*.tfstate* terraform/tfplan
	rm -f ansible/ansible.log ansible/ssh-key.pem ansible/inventory/hosts.ini
	rm -f evidence/*.txt evidence/*.json
