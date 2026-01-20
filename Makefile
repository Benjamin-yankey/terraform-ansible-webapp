.PHONY: all init plan apply deploy verify destroy clean help

# Variables
TERRAFORM_DIR := terraform
ANSIBLE_DIR := ansible
EVIDENCE_DIR := evidence
TERRAFORM := terraform
ANSIBLE_PLAYBOOK := ansible-playbook
SLEEP_TIME := 90

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

all: init plan apply wait deploy verify ## Run complete deployment pipeline

help: ## Show this help message
	@echo "$(BLUE)Terraform + Ansible Web App Deployment$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) fmt -check
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) validate
	@echo "$(GREEN)✓ Configuration validated$(NC)"

plan: ## Create Terraform execution plan
	@echo "$(BLUE)Creating Terraform plan...$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) plan -out=tfplan
	@echo "$(GREEN)✓ Plan created: $(TERRAFORM_DIR)/tfplan$(NC)"

apply: ## Apply Terraform configuration
	@echo "$(BLUE)Applying Terraform configuration...$(NC)"
	@mkdir -p $(EVIDENCE_DIR)
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) apply tfplan | tee ../$(EVIDENCE_DIR)/APPLY.txt
	@echo "$(GREEN)✓ Infrastructure provisioned$(NC)"
	@echo "$(YELLOW)Saving SSH key...$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) output -raw ssh_private_key > ../$(ANSIBLE_DIR)/ssh-key.pem
	@chmod 400 $(ANSIBLE_DIR)/ssh-key.pem
	@echo "$(GREEN)✓ SSH key saved$(NC)"

outputs: ## Display Terraform outputs
	@echo "$(BLUE)Terraform Outputs:$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) output

wait: ## Wait for EC2 instance to be ready
	@echo "$(YELLOW)Waiting $(SLEEP_TIME) seconds for EC2 to initialize...$(NC)"
	@sleep $(SLEEP_TIME)
	@echo "$(GREEN)✓ Wait complete$(NC)"

test-connection: ## Test Ansible connectivity
	@echo "$(BLUE)Testing Ansible connectivity...$(NC)"
	@cd $(ANSIBLE_DIR) && ansible webservers -m ping -i inventory/hosts.ini
	@echo "$(GREEN)✓ Connection successful$(NC)"

deploy: ## Run Ansible playbook
	@echo "$(BLUE)Running Ansible playbook...$(NC)"
	@cd $(ANSIBLE_DIR) && $(ANSIBLE_PLAYBOOK) -i inventory/hosts.ini site.yml
	@echo "$(GREEN)✓ Application deployed$(NC)"

verify: ## Verify deployment
	@echo "$(BLUE)Verifying deployment...$(NC)"
	@mkdir -p $(EVIDENCE_DIR)
	@PUBLIC_IP=$$(cd $(TERRAFORM_DIR) && $(TERRAFORM) output -raw public_ip) && \
		echo "$(YELLOW)Testing HTTP endpoint: http://$$PUBLIC_IP$(NC)" && \
		curl -v http://$$PUBLIC_IP 2>&1 | tee $(EVIDENCE_DIR)/curl-output.txt
	@echo ""
	@echo "$(GREEN)✓ Verification complete$(NC)"
	@echo "$(YELLOW)Web URL: $$(cd $(TERRAFORM_DIR) && $(TERRAFORM) output -raw webapp_url)$(NC)"

curl: ## Quick curl test
	@PUBLIC_IP=$$(cd $(TERRAFORM_DIR) && $(TERRAFORM) output -raw public_ip) && \
		curl -s http://$$PUBLIC_IP | head -n 20

open: ## Open web app in browser
	@PUBLIC_IP=$$(cd $(TERRAFORM_DIR) && $(TERRAFORM) output -raw public_ip) && \
		echo "$(BLUE)Opening http://$$PUBLIC_IP$(NC)" && \
		(xdg-open http://$$PUBLIC_IP 2>/dev/null || open http://$$PUBLIC_IP 2>/dev/null || echo "Please open http://$$PUBLIC_IP manually")

ssh: ## SSH into the EC2 instance
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) output -raw ssh_command | sh

destroy: ## Destroy all infrastructure
	@echo "$(RED)Destroying infrastructure...$(NC)"
	@mkdir -p $(EVIDENCE_DIR)
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) destroy -auto-approve | tee ../$(EVIDENCE_DIR)/DESTROY.txt
	@echo "$(GREEN)✓ Infrastructure destroyed$(NC)"

clean: ## Clean generated files
	@echo "$(YELLOW)Cleaning generated files...$(NC)"
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -f $(TERRAFORM_DIR)/terraform.tfstate*
	@rm -f $(TERRAFORM_DIR)/tfplan
	@rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -f $(ANSIBLE_DIR)/ssh-key.pem
	@rm -f $(ANSIBLE_DIR)/ansible.log
	@rm -f $(ANSIBLE_DIR)/inventory/hosts.ini
	@rm -rf $(ANSIBLE_DIR)/__pycache__
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

evidence: ## Generate evidence summary
	@echo "$(BLUE)Generating evidence summary...$(NC)"
	@mkdir -p $(EVIDENCE_DIR)
	@echo "# Deployment Evidence" > $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "## Deployment Summary" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "- Date: $$(date)" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) output deployment_summary >> ../$(EVIDENCE_DIR)/EVIDENCE.md
	@echo "" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "## Files" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "- APPLY.txt: Terraform apply output" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "- DESTROY.txt: Terraform destroy output" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "- curl-output.txt: HTTP verification" >> $(EVIDENCE_DIR)/EVIDENCE.md
	@echo "$(GREEN)✓ Evidence summary created$(NC)"

status: ## Show deployment status
	@echo "$(BLUE)Deployment Status:$(NC)"
	@echo ""
	@if [ -f "$(TERRAFORM_DIR)/terraform.tfstate" ]; then \
		echo "$(GREEN)✓ Infrastructure State: EXISTS$(NC)"; \
		cd $(TERRAFORM_DIR) && $(TERRAFORM) output deployment_summary; \
	else \
		echo "$(RED)✗ Infrastructure State: NOT FOUND$(NC)"; \
	fi

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) fmt -recursive
	@echo "$(GREEN)✓ Files formatted$(NC)"

lint: ## Lint configuration files
	@echo "$(BLUE)Linting configuration...$(NC)"
	@cd $(TERRAFORM_DIR) && $(TERRAFORM) fmt -check -recursive
	@cd $(ANSIBLE_DIR) && ansible-lint site.yml || echo "$(YELLOW)ansible-lint not installed$(NC)"
	@echo "$(GREEN)✓ Linting complete$(NC)"