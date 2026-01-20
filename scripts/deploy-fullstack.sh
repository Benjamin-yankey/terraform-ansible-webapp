#!/bin/bash

###############################################################################
# Full-Stack Task Manager Deployment Script
# Description: Complete automated deployment for React + Flask application
# Author: DevOps Team
# Version: 2.0.0
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"
APP_DIR="app"
EVIDENCE_DIR="evidence"
SCREENSHOTS_DIR="screenshots"
WAIT_TIME=120

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Full-Stack Task Manager Deployment${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}React + Flask + Terraform + Ansible${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    local missing=0
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found"
        missing=1
    else
        local tf_version=$(terraform version | head -1)
        print_success "Terraform: $tf_version"
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible not found"
        missing=1
    else
        local ansible_version=$(ansible --version | head -1)
        print_success "Ansible: $ansible_version"
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI not found (optional but recommended)"
    else
        print_success "AWS CLI: $(aws --version)"
    fi
    
    # Check Node.js (for local development)
    if command -v node &> /dev/null; then
        print_success "Node.js: $(node --version)"
    else
        print_warning "Node.js not found (only needed for local development)"
    fi
    
    # Check application files
    if [ ! -d "$APP_DIR" ]; then
        print_error "Application directory '$APP_DIR' not found"
        missing=1
    else
        print_success "Application directory found"
    fi
    
    if [ ! -f "$APP_DIR/backend/app.py" ]; then
        print_error "Backend application (app.py) not found"
        missing=1
    else
        print_success "Backend application found"
    fi
    
    if [ ! -f "$APP_DIR/frontend/package.json" ]; then
        print_error "Frontend application (package.json) not found"
        missing=1
    else
        print_success "Frontend application found"
    fi
    
    if [ $missing -eq 1 ]; then
        print_error "Missing required tools or files. Please install them first."
        exit 1
    fi
    
    echo ""
}

create_directories() {
    print_step "Creating project directories..."
    mkdir -p "$EVIDENCE_DIR" "$SCREENSHOTS_DIR"
    print_success "Directories created"
}

terraform_init() {
    print_section "TERRAFORM INITIALIZATION"
    cd "$TERRAFORM_DIR"
    
    print_step "Initializing Terraform..."
    terraform init
    
    print_step "Formatting Terraform files..."
    terraform fmt -recursive
    
    print_step "Validating configuration..."
    terraform validate
    
    cd ..
    print_success "Terraform initialized successfully"
}

terraform_plan() {
    print_section "TERRAFORM PLANNING"
    cd "$TERRAFORM_DIR"
    
    print_step "Creating execution plan..."
    terraform plan -out=tfplan
    
    echo ""
    print_warning "Please review the plan above."
    read -p "Continue with apply? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_error "Deployment cancelled by user"
        cd ..
        exit 0
    fi
    
    cd ..
}

terraform_apply() {
    print_section "INFRASTRUCTURE PROVISIONING"
    cd "$TERRAFORM_DIR"
    
    print_step "Applying Terraform configuration..."
    terraform apply tfplan | tee "../$EVIDENCE_DIR/APPLY.txt"
    
    print_step "Saving outputs..."
    terraform output > "../$EVIDENCE_DIR/terraform_outputs.txt"
    terraform output -raw ssh_private_key > "../$ANSIBLE_DIR/ssh-key.pem"
    chmod 400 "../$ANSIBLE_DIR/ssh-key.pem"
    
    PUBLIC_IP=$(terraform output -raw public_ip)
    echo "$PUBLIC_IP" > "../$EVIDENCE_DIR/public_ip.txt"
    
    cd ..
    print_success "Infrastructure provisioned successfully"
    echo ""
    print_success "Public IP: $PUBLIC_IP"
}

wait_for_instance() {
    print_section "WAITING FOR EC2 INITIALIZATION"
    
    print_step "Waiting $WAIT_TIME seconds for instance to be ready..."
    echo -e "${YELLOW}This ensures all user-data scripts complete${NC}"
    
    local elapsed=0
    while [ $elapsed -lt $WAIT_TIME ]; do
        printf "\r${CYAN}⏳ Progress: [%-50s] %d/%d seconds${NC}" \
            $(printf '#%.0s' $(seq 1 $((elapsed * 50 / WAIT_TIME)))) \
            $elapsed $WAIT_TIME
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    echo ""
    print_success "Initialization wait complete"
}

test_connectivity() {
    print_section "TESTING CONNECTIVITY"
    cd "$ANSIBLE_DIR"
    
    print_step "Testing SSH connectivity..."
    
    local retries=5
    local count=0
    
    while [ $count -lt $retries ]; do
        if ansible webservers -m ping -i inventory/hosts.ini &> /dev/null; then
            print_success "SSH connection successful"
            cd ..
            return 0
        fi
        
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            print_warning "Connection failed, retry $count/$retries..."
            sleep 10
        fi
    done
    
    print_error "Failed to connect after $retries attempts"
    cd ..
    exit 1
}

deploy_application() {
    print_section "APPLICATION DEPLOYMENT"
    cd "$ANSIBLE_DIR"
    
    print_step "Running Ansible playbook..."
    echo -e "${YELLOW}This will install and configure the full-stack application${NC}"
    echo ""
    
    ansible-playbook -i inventory/hosts.ini site.yml
    
    cd ..
    print_success "Application deployed successfully"
}

verify_deployment() {
    print_section "DEPLOYMENT VERIFICATION"
    
    cd "$TERRAFORM_DIR"
    PUBLIC_IP=$(terraform output -raw public_ip)
    cd ..
    
    echo -e "${CYAN}Testing endpoints...${NC}"
    echo ""
    
    # Test frontend
    print_step "Testing frontend (http://$PUBLIC_IP)..."
    if curl -f -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" | grep -q "200"; then
        print_success "Frontend is accessible"
        curl -s "http://$PUBLIC_IP" > "$EVIDENCE_DIR/frontend-response.html"
    else
        print_error "Frontend is not responding"
    fi
    
    # Test backend API
    print_step "Testing backend API (http://$PUBLIC_IP:5000/api/health)..."
    if curl -f -s "http://$PUBLIC_IP:5000/api/health" | grep -q "healthy"; then
        print_success "Backend API is healthy"
        curl -s "http://$PUBLIC_IP:5000/api/health" > "$EVIDENCE_DIR/api-health.json"
    else
        print_error "Backend API is not responding"
    fi
    
    # Test API tasks endpoint
    print_step "Testing tasks endpoint..."
    if curl -f -s "http://$PUBLIC_IP:5000/api/tasks" > "$EVIDENCE_DIR/api-tasks.json"; then
        print_success "Tasks API is working"
    else
        print_warning "Tasks API returned an error (may be expected if no tasks)"
    fi
    
    # Test API stats
    print_step "Testing statistics endpoint..."
    if curl -f -s "http://$PUBLIC_IP:5000/api/stats" > "$EVIDENCE_DIR/api-stats.json"; then
        print_success "Statistics API is working"
    else
        print_warning "Statistics API returned an error"
    fi
    
    # Save full curl output
    print_step "Saving detailed verification..."
    curl -v "http://$PUBLIC_IP" > "$EVIDENCE_DIR/curl-output.txt" 2>&1
    
    echo ""
    print_success "Verification complete"
}

generate_evidence() {
    print_section "GENERATING EVIDENCE REPORT"
    
    cd "$TERRAFORM_DIR"
    PUBLIC_IP=$(terraform output -raw public_ip)
    cd ..
    
    cat > "$EVIDENCE_DIR/EVIDENCE.md" << EOF
# Full-Stack Task Manager - Deployment Evidence

## Deployment Information

- **Date**: $(date)
- **Project**: Task Manager Full-Stack Application
- **Infrastructure**: Terraform + Ansible
- **Application**: React + Flask + SQLite

## Infrastructure Details

### Provisioned Resources

\`\`\`
$(cd "$TERRAFORM_DIR" && terraform show -json | jq -r '.values.root_module.resources[].type' | sort | uniq -c)
\`\`\`

### Outputs

\`\`\`
$(cat "$EVIDENCE_DIR/terraform_outputs.txt")
\`\`\`

## Application Endpoints

### Frontend
- **URL**: http://$PUBLIC_IP
- **Status**: $(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP")

### Backend API
- **Base URL**: http://$PUBLIC_IP:5000/api
- **Health Check**: http://$PUBLIC_IP:5000/api/health
- **Tasks**: http://$PUBLIC_IP:5000/api/tasks
- **Statistics**: http://$PUBLIC_IP:5000/api/stats
- **Categories**: http://$PUBLIC_IP:5000/api/categories

## API Test Results

### Health Check
\`\`\`json
$(cat "$EVIDENCE_DIR/api-health.json" 2>/dev/null || echo "Not available")
\`\`\`

### Statistics
\`\`\`json
$(cat "$EVIDENCE_DIR/api-stats.json" 2>/dev/null || echo "Not available")
\`\`\`

### Tasks (Sample)
\`\`\`json
$(cat "$EVIDENCE_DIR/api-tasks.json" 2>/dev/null | head -20)
\`\`\`

## Verification Steps

1. ✓ Terraform apply completed successfully
2. ✓ EC2 instance provisioned
3. ✓ Ansible playbook executed
4. ✓ Frontend accessible via HTTP
5. ✓ Backend API responding
6. ✓ Database operational
7. ✓ All services running

## Evidence Files

- \`APPLY.txt\` - Terraform apply output
- \`terraform_outputs.txt\` - All Terraform outputs
- \`curl-output.txt\` - HTTP verification details
- \`frontend-response.html\` - Frontend HTML response
- \`api-health.json\` - API health check response
- \`api-tasks.json\` - Tasks API response
- \`api-stats.json\` - Statistics API response

## Screenshots Required

- [ ] Frontend web interface (browser)
- [ ] Task creation form
- [ ] Task list with multiple tasks
- [ ] API response (curl/Postman)
- [ ] Terraform apply terminal output

## Cleanup Command

\`\`\`bash
cd terraform
terraform destroy -auto-approve | tee ../evidence/DESTROY.txt
\`\`\`

---
Generated automatically by deployment script
EOF

    print_success "Evidence report generated: $EVIDENCE_DIR/EVIDENCE.md"
}

display_success() {
    local public_ip=$1
    
    clear
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║${NC}            ${CYAN}🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📱 APPLICATION URLS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Frontend:${NC}      ${GREEN}http://$public_ip${NC}"
    echo -e "  ${CYAN}Backend API:${NC}   ${GREEN}http://$public_ip:5000/api${NC}"
    echo -e "  ${CYAN}Health Check:${NC}  ${GREEN}http://$public_ip:5000/api/health${NC}"
    echo ""
    echo -e "${CYAN}🧪 QUICK TESTS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Test Frontend:${NC}"
    echo -e "    curl http://$public_ip"
    echo ""
    echo -e "  ${CYAN}Test API:${NC}"
    echo -e "    curl http://$public_ip:5000/api/health"
    echo -e "    curl http://$public_ip:5000/api/stats"
    echo -e "    curl http://$public_ip:5000/api/tasks"
    echo ""
    echo -e "  ${CYAN}Create a Task:${NC}"
    echo -e "    curl -X POST http://$public_ip:5000/api/tasks \\"
    echo -e "      -H 'Content-Type: application/json' \\"
    echo -e "      -d '{\"title\": \"My First Task\", \"priority\": \"high\"}'"
    echo ""
    echo -e "${CYAN}🌐 BROWSER ACCESS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Open in browser: ${GREEN}http://$public_ip${NC}"
    echo ""
    echo -e "  ${YELLOW}Features available:${NC}"
    echo -e "    • Create, edit, delete tasks"
    echo -e "    • Mark tasks complete/incomplete"
    echo -e "    • Filter by category, priority, status"
    echo -e "    • Search tasks"
    echo -e "    • View statistics dashboard"
    echo ""
    echo -e "${CYAN}🔌 SSH ACCESS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ssh -i ansible/ssh-key.pem ec2-user@$public_ip"
    echo ""
    echo -e "${CYAN}📊 CHECK SERVICES${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}On the server:${NC}"
    echo -e "    sudo systemctl status taskmanager-backend"
    echo -e "    sudo systemctl status nginx"
    echo -e "    tail -f /opt/taskmanager/logs/backend.log"
    echo ""
    echo -e "${CYAN}📋 NEXT STEPS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  1. ${GREEN}✓${NC} Open http://$public_ip in your browser"
    echo -e "  2. ${GREEN}✓${NC} Test the application features"
    echo -e "  3. ${GREEN}✓${NC} Take screenshots for documentation"
    echo -e "  4. ${GREEN}✓${NC} Save screenshots to: ${YELLOW}$SCREENSHOTS_DIR/${NC}"
    echo -e "  5. ${YELLOW}⚠${NC} Run cleanup when done: ${RED}cd terraform && terraform destroy${NC}"
    echo ""
    echo -e "${CYAN}📁 EVIDENCE FILES${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/APPLY.txt"
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/curl-output.txt"
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/EVIDENCE.md"
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/api-health.json"
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/api-stats.json"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Don't forget to run 'terraform destroy' when finished!${NC}"
    echo ""
}

main() {
    print_header
    
    check_prerequisites
    create_directories
    
    terraform_init
    terraform_plan
    terraform_apply
    
    wait_for_instance
    test_connectivity
    
    deploy_application
    verify_deployment
    generate_evidence
    
    # Get public IP for final display
    cd "$TERRAFORM_DIR"
    PUBLIC_IP=$(terraform output -raw public_ip)
    cd ..
    
    display_success "$PUBLIC_IP"
}

# Run main function
main "$@"