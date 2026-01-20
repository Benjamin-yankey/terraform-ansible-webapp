#!/bin/bash

###############################################################################
# Terraform + Ansible Deployment Script
# Description: Automated deployment pipeline for web application
# Author: DevOps Team
# Version: 1.0.0
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"
EVIDENCE_DIR="evidence"
SCREENSHOTS_DIR="screenshots"
WAIT_TIME=90

# Functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Terraform + Ansible Web App Deployment${NC}                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${MAGENTA}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing=0
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found"
        missing=1
    else
        print_success "Terraform $(terraform version | head -1)"
    fi
    
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible not found"
        missing=1
    else
        print_success "Ansible $(ansible --version | head -1)"
    fi
    
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI not found (optional)"
    else
        print_success "AWS CLI $(aws --version)"
    fi
    
    if [ $missing -eq 1 ]; then
        print_error "Missing required tools. Please install them first."
        exit 1
    fi
    
    echo ""
}

create_directories() {
    print_step "Creating project directories..."
    mkdir -p "$EVIDENCE_DIR" "$SCREENSHOTS_DIR"
    print_success "Directories created"
    echo ""
}

terraform_init() {
    print_step "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    terraform init
    cd ..
    print_success "Terraform initialized"
    echo ""
}

terraform_validate() {
    print_step "Validating Terraform configuration..."
    cd "$TERRAFORM_DIR"
    terraform fmt -recursive
    terraform validate
    cd ..
    print_success "Configuration validated"
    echo ""
}

terraform_plan() {
    print_step "Creating Terraform execution plan..."
    cd "$TERRAFORM_DIR"
    terraform plan -out=tfplan
    cd ..
    print_success "Execution plan created"
    echo ""
}

terraform_apply() {
    print_step "Applying Terraform configuration..."
    cd "$TERRAFORM_DIR"
    terraform apply tfplan | tee "../$EVIDENCE_DIR/APPLY.txt"
    cd ..
    print_success "Infrastructure provisioned"
    echo ""
}

save_terraform_outputs() {
    print_step "Saving Terraform outputs..."
    cd "$TERRAFORM_DIR"
    
    # Save SSH key
    terraform output -raw ssh_private_key > "../$ANSIBLE_DIR/ssh-key.pem"
    chmod 400 "../$ANSIBLE_DIR/ssh-key.pem"
    
    # Get public IP
    PUBLIC_IP=$(terraform output -raw public_ip)
    echo "$PUBLIC_IP" > "../$EVIDENCE_DIR/public_ip.txt"
    
    # Save all outputs
    terraform output > "../$EVIDENCE_DIR/terraform_outputs.txt"
    
    cd ..
    print_success "Outputs saved"
    echo ""
}

wait_for_instance() {
    print_step "Waiting $WAIT_TIME seconds for EC2 instance to initialize..."
    
    local elapsed=0
    while [ $elapsed -lt $WAIT_TIME ]; do
        printf "\r${YELLOW}⏳ Elapsed: %02d:%02d / %02d:%02d${NC}" \
            $((elapsed/60)) $((elapsed%60)) $((WAIT_TIME/60)) $((WAIT_TIME%60))
        sleep 5
        elapsed=$((elapsed+5))
    done
    
    echo ""
    print_success "Wait complete"
    echo ""
}

test_ansible_connection() {
    print_step "Testing Ansible connectivity..."
    cd "$ANSIBLE_DIR"
    
    local retries=3
    local count=0
    
    while [ $count -lt $retries ]; do
        if ansible webservers -m ping -i inventory/hosts.ini &> /dev/null; then
            print_success "Connection successful"
            cd ..
            echo ""
            return 0
        fi
        
        count=$((count+1))
        if [ $count -lt $retries ]; then
            print_warning "Connection failed, retrying ($count/$retries)..."
            sleep 10
        fi
    done
    
    print_error "Failed to connect after $retries attempts"
    cd ..
    exit 1
}

run_ansible_playbook() {
    print_step "Running Ansible playbook..."
    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory/hosts.ini site.yml
    cd ..
    print_success "Application deployed"
    echo ""
}

verify_deployment() {
    print_step "Verifying deployment..."
    
    cd "$TERRAFORM_DIR"
    PUBLIC_IP=$(terraform output -raw public_ip)
    cd ..
    
    echo -e "${CYAN}Testing HTTP endpoint: http://$PUBLIC_IP${NC}"
    
    # Test with curl
    if curl -f -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" | grep -q "200"; then
        print_success "HTTP endpoint is responding"
        
        # Save full curl output
        curl -v "http://$PUBLIC_IP" > "$EVIDENCE_DIR/curl-output.txt" 2>&1
        
        # Save HTML content
        curl -s "http://$PUBLIC_IP" > "$EVIDENCE_DIR/webpage-content.html"
    else
        print_error "HTTP endpoint is not responding correctly"
        exit 1
    fi
    
    echo ""
}

display_success_info() {
    local public_ip=$1
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}            ${CYAN}🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📍 Web Application URL:${NC}"
    echo -e "   ${YELLOW}http://$public_ip${NC}"
    echo ""
    echo -e "${CYAN}🔗 Quick Actions:${NC}"
    echo -e "   ${YELLOW}• Open in browser:${NC} xdg-open http://$public_ip"
    echo -e "   ${YELLOW}• Test with curl:${NC}  curl http://$public_ip"
    echo -e "   ${YELLOW}• SSH to server:${NC}   make ssh"
    echo ""
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo -e "   1. Open http://$public_ip in your browser"
    echo -e "   2. Take a screenshot of the webpage"
    echo -e "   3. Save screenshot to: ${YELLOW}$SCREENSHOTS_DIR/${NC}"
    echo -e "   4. Run ${YELLOW}'make destroy'${NC} when finished to cleanup resources"
    echo ""
    echo -e "${CYAN}📁 Evidence Files:${NC}"
    echo -e "   • $EVIDENCE_DIR/APPLY.txt"
    echo -e "   • $EVIDENCE_DIR/curl-output.txt"
    echo -e "   • $EVIDENCE_DIR/webpage-content.html"
    echo -e "   • $EVIDENCE_DIR/terraform_outputs.txt"
    echo ""
}

generate_evidence_report() {
    print_step "Generating evidence report..."
    
    cat > "$EVIDENCE_DIR/EVIDENCE.md" << EOF
# Deployment Evidence Report

## Project Information
- **Project Name:** Terraform + Ansible Web App
- **Deployment Date:** $(date)
- **Deployed By:** $USER

## Infrastructure Details

### Terraform Apply
\`\`\`
$(head -n 20 "$EVIDENCE_DIR/APPLY.txt")
...
See APPLY.txt for full output
\`\`\`

### Deployed Resources
$(cd "$TERRAFORM_DIR" && terraform show -json | jq -r '.values.root_module.resources[].type' | sort | uniq -c)

### Outputs
\`\`\`
$(cat "$EVIDENCE_DIR/terraform_outputs.txt")
\`\`\`

## Verification

### HTTP Response
- Status: $(grep -oP '(?<=< HTTP/1.1 )\d+' "$EVIDENCE_DIR/curl-output.txt" | head -1)
- Content-Type: $(grep -oP '(?<=< Content-Type: ).*' "$EVIDENCE_DIR/curl-output.txt" | head -1)

### Screenshot
- Location: ../screenshots/
- Filename: [Please add screenshot filename]

## Cleanup
- Run: \`make destroy\`
- Evidence: See DESTROY.txt after cleanup

---
Generated by deployment automation script
EOF

    print_success "Evidence report generated: $EVIDENCE_DIR/EVIDENCE.md"
    echo ""
}

main() {
    print_header
    
    check_prerequisites
    create_directories
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}PHASE 1: TERRAFORM PROVISIONING${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    terraform_init
    terraform_validate
    terraform_plan
    terraform_apply
    save_terraform_outputs
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}PHASE 2: WAITING FOR INITIALIZATION${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    wait_for_instance
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}PHASE 3: ANSIBLE CONFIGURATION${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    test_ansible_connection
    run_ansible_playbook
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}PHASE 4: VERIFICATION${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    verify_deployment
    generate_evidence_report
    
    # Get public IP for final display
    cd "$TERRAFORM_DIR"
    PUBLIC_IP=$(terraform output -raw public_ip)
    cd ..
    
    display_success_info "$PUBLIC_IP"
}

# Run main function
main "$@"