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
WAIT_TIME=60  # Reduced from 120 seconds

# Store public IP globally
PUBLIC_IP=""

print_header() {
    clear
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
        print_step "Install with: brew install terraform"
        missing=1
    else
        local tf_version=$(terraform version | head -1)
        print_success "Terraform: $tf_version"
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible not found"
        print_step "Install with: brew install ansible"
        missing=1
    else
        local ansible_version=$(ansible --version | head -1)
        print_success "Ansible: $ansible_version"
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI not found (optional but recommended)"
        print_step "Install with: brew install awscli"
    else
        print_success "AWS CLI: $(aws --version)"
    fi
    
    # Check jq (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        print_error "jq not found"
        print_step "Install with: brew install jq"
        missing=1
    else
        print_success "jq: $(jq --version)"
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 not found"
        print_step "Install with: brew install python"
        missing=1
    else
        print_success "Python: $(python3 --version)"
    fi
    
    # Check application files
    if [ ! -d "$APP_DIR" ]; then
        print_error "Application directory '$APP_DIR' not found"
        missing=1
    else
        print_success "Application directory found"
    fi
    
    # Check backend (using your actual path)
    if [ ! -f "$APP_DIR/database/app.py" ]; then
        print_error "Backend application (app.py) not found at $APP_DIR/database/app.py"
        missing=1
    else
        print_success "Backend application found"
    fi
    
    # Check frontend (optional, since you might not have it)
    if [ ! -f "$APP_DIR/frontend/package.json" ]; then
        print_warning "Frontend application (package.json) not found"
        print_step "Will deploy backend-only configuration"
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
    mkdir -p "$EVIDENCE_DIR" "$SCREENSHOTS_DIR" "$ANSIBLE_DIR/inventory"
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
    
    # Save SSH key with proper permissions
    if terraform output -raw ssh_private_key > "../$ANSIBLE_DIR/ssh-key.pem" 2>/dev/null; then
        chmod 400 "../$ANSIBLE_DIR/ssh-key.pem"
        print_success "SSH key saved"
    else
        print_warning "No SSH key output found"
    fi
    
    # Get public IP
    if terraform output -raw public_ip > "../$EVIDENCE_DIR/public_ip.txt" 2>/dev/null; then
        PUBLIC_IP=$(cat "../$EVIDENCE_DIR/public_ip.txt")
        print_success "Public IP: $PUBLIC_IP"
    else
        print_error "Could not get public IP from Terraform"
        exit 1
    fi
    
    cd ..
    print_success "Infrastructure provisioned successfully"
}

create_ansible_inventory() {
    print_section "CONFIGURING ANSIBLE"
    
    if [ -z "$PUBLIC_IP" ]; then
        if [ -f "$EVIDENCE_DIR/public_ip.txt" ]; then
            PUBLIC_IP=$(cat "$EVIDENCE_DIR/public_ip.txt")
        else
            print_error "No public IP available"
            exit 1
        fi
    fi
    
    # Create inventory file
    INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.ini"
    
    cat > "$INVENTORY_FILE" << EOF
[webservers]
web1 ansible_host=$PUBLIC_IP ansible_user=ec2-user ansible_ssh_private_key_file=../ansible/ssh-key.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
EOF
    
    print_success "Ansible inventory created at: $INVENTORY_FILE"
    echo ""
    echo "Inventory contents:"
    cat "$INVENTORY_FILE"
    echo ""
}

wait_for_instance() {
    print_section "WAITING FOR EC2 INITIALIZATION"
    
    if [ -z "$PUBLIC_IP" ]; then
        print_error "No public IP available"
        return 1
    fi
    
    print_step "Waiting $WAIT_TIME seconds for instance to be ready..."
    echo -e "${YELLOW}Waiting for SSH to become available...${NC}"
    
    local elapsed=0
    local connected=false
    
    while [ $elapsed -lt $WAIT_TIME ] && [ "$connected" = false ]; do
        printf "\r${CYAN}⏳ Testing connection [%d/%d seconds]${NC}" $elapsed $WAIT_TIME
        
        # Test SSH connection
        if ssh -i "$ANSIBLE_DIR/ssh-key.pem" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@"$PUBLIC_IP" "exit" 2>/dev/null; then
            connected=true
            printf "\r${GREEN}✓ Connected after %d seconds${NC}\n" $elapsed
            break
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    if [ "$connected" = false ]; then
        print_error "Could not connect to instance after $WAIT_TIME seconds"
        print_warning "Continuing anyway, but Ansible may fail..."
    fi
    
    print_success "Instance ready check complete"
}

test_connectivity() {
    print_section "TESTING CONNECTIVITY"
    
    if [ -z "$PUBLIC_IP" ]; then
        print_error "No public IP available"
        return 1
    fi
    
    print_step "Testing SSH connectivity to $PUBLIC_IP..."
    
    if ssh -i "$ANSIBLE_DIR/ssh-key.pem" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@"$PUBLIC_IP" "echo 'SSH connection successful!'"; then
        print_success "SSH connection successful"
        return 0
    else
        print_error "SSH connection failed"
        print_warning "Will attempt to continue anyway..."
        return 1
    fi
}

create_ansible_playbook() {
    print_section "CREATING ANSIBLE PLAYBOOK"
    
    PLAYBOOK_FILE="$ANSIBLE_DIR/site.yml"
    
    cat > "$PLAYBOOK_FILE" << 'EOF'
---
- name: Deploy Task Manager Application
  hosts: webservers
  become: yes
  gather_facts: yes
  
  vars:
    app_user: ec2-user
    app_group: ec2-user
    app_name: taskmanager
    app_dir: /opt/{{ app_name }}
    backend_port: 5000
    
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
      
    - name: Install required packages
      package:
        name:
          - python3
          - python3-pip
          - python3-venv
          - git
          - curl
          - wget
          - sqlite3
        state: present
        
    - name: Create application directory
      file:
        path: "{{ app_dir }}"
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        mode: '0755'
        
    - name: Copy application files
      copy:
        src: "../../app/"
        dest: "{{ app_dir }}"
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        
    - name: Create virtual environment
      command:
        cmd: python3 -m venv venv
        chdir: "{{ app_dir }}/database"
        creates: "{{ app_dir }}/database/venv/bin/python"
        
    - name: Install Python dependencies
      pip:
        requirements: "{{ app_dir }}/database/requirements.txt"
        virtualenv: "{{ app_dir }}/database/venv"
        virtualenv_command: python3 -m venv
        
    - name: Create database directory
      file:
        path: /var/lib/{{ app_name }}
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        mode: '0755'
        
    - name: Create systemd service file
      copy:
        dest: /etc/systemd/system/{{ app_name }}.service
        content: |
          [Unit]
          Description=Task Manager Flask Application
          After=network.target
          Requires=network.target
          
          [Service]
          Type=simple
          User={{ app_user }}
          Group={{ app_group }}
          WorkingDirectory={{ app_dir }}/database
          Environment="PATH={{ app_dir }}/database/venv/bin"
          Environment="FLASK_ENV=production"
          Environment="SECRET_KEY=your-production-secret-key-change-this"
          ExecStart={{ app_dir }}/database/venv/bin/python app.py
          Restart=always
          RestartSec=10
          
          [Install]
          WantedBy=multi-user.target
          
    - name: Create logs directory
      file:
        path: /var/log/{{ app_name }}
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_user }}"
        mode: '0755'
        
    - name: Reload systemd daemon
      systemd:
        daemon_reload: yes
        
    - name: Enable and start application service
      systemd:
        name: "{{ app_name }}"
        state: started
        enabled: yes
        daemon_reload: yes
        
    - name: Wait for application to start
      wait_for:
        port: "{{ backend_port }}"
        delay: 5
        timeout: 60
        
    - name: Test application endpoint
      uri:
        url: "http://localhost:{{ backend_port }}/api/health"
        method: GET
        return_content: yes
      register: health_check
      until: health_check.status == 200
      retries: 10
      delay: 5
      
    - name: Show health check result
      debug:
        msg: "Application health check: {{ health_check.json }}"
EOF
    
    print_success "Ansible playbook created at: $PLAYBOOK_FILE"
    
    # Also create a simple requirements.txt for Flask app
    if [ ! -f "$APP_DIR/database/requirements.txt" ]; then
        cat > "$APP_DIR/database/requirements.txt" << 'REQ'
Flask==2.3.3
Flask-CORS==4.0.0
Flask-SQLAlchemy==3.0.5
SQLAlchemy==2.0.23
REQ
        print_success "Created requirements.txt for Flask app"
    fi
}

deploy_application() {
    print_section "APPLICATION DEPLOYMENT"
    cd "$ANSIBLE_DIR"
    
    # Create playbook if doesn't exist
    if [ ! -f "site.yml" ]; then
        create_ansible_playbook
    fi
    
    # Create inventory if doesn't exist
    if [ ! -f "inventory/hosts.ini" ]; then
        create_ansible_inventory
    fi
    
    print_step "Running Ansible playbook..."
    echo -e "${YELLOW}This will install and configure the Flask application${NC}"
    echo ""
    
    ansible-playbook -i inventory/hosts.ini site.yml -v
    
    local result=$?
    cd ..
    
    if [ $result -eq 0 ]; then
        print_success "Application deployed successfully"
    else
        print_error "Ansible playbook failed"
        print_warning "Continuing with verification anyway..."
    fi
}

verify_deployment() {
    print_section "DEPLOYMENT VERIFICATION"
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(cat "$EVIDENCE_DIR/public_ip.txt" 2>/dev/null || echo "")
        if [ -z "$PUBLIC_IP" ]; then
            print_error "No public IP available for verification"
            return 1
        fi
    fi
    
    echo -e "${CYAN}Testing endpoints on $PUBLIC_IP...${NC}"
    echo ""
    
    # Test backend API
    print_step "Testing backend API (http://$PUBLIC_IP:5000/api/health)..."
    
    local max_retries=10
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        printf "\r${CYAN}Attempt $((retry_count + 1))/$max_retries...${NC}"
        
        if curl -f -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$PUBLIC_IP:5000/api/health" | grep -q "200"; then
            success=true
            printf "\r${GREEN}✓ Backend API is healthy${NC}\n"
            curl -s "http://$PUBLIC_IP:5000/api/health" > "$EVIDENCE_DIR/api-health.json"
            break
        fi
        
        sleep 5
        retry_count=$((retry_count + 1))
    done
    
    if [ "$success" = false ]; then
        print_error "Backend API is not responding after $max_retries attempts"
        return 1
    fi
    
    # Test other endpoints
    local endpoints=("tasks" "stats" "")
    for endpoint in "${endpoints[@]}"; do
        if [ -n "$endpoint" ]; then
            url="http://$PUBLIC_IP:5000/api/$endpoint"
            filename="api-$endpoint.json"
        else
            url="http://$PUBLIC_IP:5000/"
            filename="api-root.json"
        fi
        
        print_step "Testing $url..."
        if curl -f -s --connect-timeout 5 "$url" > "$EVIDENCE_DIR/$filename" 2>/dev/null; then
            print_success "✓ $endpoint endpoint working"
        else
            print_warning "⚠ $endpoint endpoint may not be available"
        fi
    done
    
    # Save full verification
    print_step "Saving detailed verification..."
    curl -v "http://$PUBLIC_IP:5000/" > "$EVIDENCE_DIR/curl-backend-output.txt" 2>&1
    
    echo ""
    print_success "Verification complete"
}

generate_evidence() {
    print_section "GENERATING EVIDENCE REPORT"
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(cat "$EVIDENCE_DIR/public_ip.txt" 2>/dev/null || echo "UNKNOWN")
    fi
    
    # Use simpler approach if jq is not working
    cat > "$EVIDENCE_DIR/EVIDENCE.md" << EOF
# Full-Stack Task Manager - Deployment Evidence

## Deployment Information

- **Date**: $(date)
- **Project**: Task Manager Flask Application
- **Infrastructure**: Terraform + Ansible
- **Application**: Flask + SQLite
- **Instance IP**: $PUBLIC_IP

## Infrastructure Details

### Terraform Outputs

\`\`\`
$(cat "$EVIDENCE_DIR/terraform_outputs.txt" 2>/dev/null || echo "No outputs available")
\`\`\`

## Application Endpoints

### Backend API
- **Base URL**: http://$PUBLIC_IP:5000/api
- **Health Check**: http://$PUBLIC_IP:5000/api/health
- **Tasks**: http://$PUBLIC_IP:5000/api/tasks
- **Statistics**: http://$PUBLIC_IP:5000/api/stats
- **Categories**: http://$PUBLIC_IP:5000/api/categories

## API Test Results

### Health Check
\`\`\`json
$(cat "$EVIDENCE_DIR/api-health.json" 2>/dev/null || echo '{"status": "Not available"}')
\`\`\`

### Statistics
\`\`\`json
$(cat "$EVIDENCE_DIR/api-stats.json" 2>/dev/null || echo '{"message": "Not available"}')
\`\`\`

## Deployment Logs

- **Terraform Apply**: [APPLY.txt](APPLY.txt)
- **SSH Key**: Generated in ansible/ssh-key.pem
- **Public IP**: $PUBLIC_IP

## Verification Status

$(if [ -f "$EVIDENCE_DIR/api-health.json" ]; then echo "✓ Backend API is responding"; else echo "✗ Backend API is not responding"; fi)
$(if [ -f "$ANSIBLE_DIR/ssh-key.pem" ]; then echo "✓ SSH key is available"; else echo "✗ SSH key not found"; fi)

## Cleanup Command

\`\`\`bash
cd terraform
terraform destroy -auto-approve
\`\`\`

---
*Generated automatically by deployment script*
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
    echo -e "${CYAN}🌐 APPLICATION URLS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Backend API:${NC}   ${GREEN}http://$public_ip:5000${NC}"
    echo -e "  ${CYAN}Health Check:${NC}  ${GREEN}http://$public_ip:5000/api/health${NC}"
    echo -e "  ${CYAN}Tasks API:${NC}     ${GREEN}http://$public_ip:5000/api/tasks${NC}"
    echo ""
    echo -e "${CYAN}🧪 QUICK TESTS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Test API Health:${NC}"
    echo -e "    curl http://$public_ip:5000/api/health"
    echo ""
    echo -e "  ${CYAN}Get All Tasks:${NC}"
    echo -e "    curl http://$public_ip:5000/api/tasks"
    echo ""
    echo -e "  ${CYAN}Create a Task:${NC}"
    echo -e "    curl -X POST http://$public_ip:5000/api/tasks \\\\"
    echo -e "      -H 'Content-Type: application/json' \\\\"
    echo -e "      -d '{\"title\": \"Test Task\", \"description\": \"From deployment\", \"priority\": \"medium\"}'"
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
    echo -e "    sudo systemctl status taskmanager"
    echo -e "    sudo journalctl -u taskmanager -f"
    echo -e "    curl http://localhost:5000/api/health"
    echo ""
    echo -e "${CYAN}📁 EVIDENCE FILES${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/EVIDENCE.md"
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/APPLY.txt"
    echo -e "  ${GREEN}✓${NC} $EVIDENCE_DIR/api-health.json"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Run cleanup when done:${NC}"
    echo -e "    cd terraform && terraform destroy -auto-approve"
    echo ""
}

main() {
    print_header
    
    check_prerequisites
    create_directories
    
    terraform_init
    terraform_plan
    terraform_apply
    
    create_ansible_inventory
    wait_for_instance
    test_connectivity
    
    create_ansible_playbook
    deploy_application
    verify_deployment
    generate_evidence
    
    display_success "$PUBLIC_IP"
}

# Run main function
main "$@"