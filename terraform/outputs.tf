output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.webapp.id
}

output "instance_state" {
  description = "EC2 instance state"
  value       = aws_instance.webapp.instance_state
}

output "public_ip" {
  description = "Public IP address of the EC2 instance (EIP)"
  value       = aws_eip.webapp_eip.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.webapp.public_dns
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.webapp.private_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.webapp_sg.id
}

output "key_pair_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.webapp_key.key_name
}

output "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  value       = local_file.private_key.filename
  sensitive   = true
}

output "ssh_private_key" {
  description = "SSH private key content (sensitive)"
  value       = tls_private_key.webapp_key.private_key_pem
  sensitive   = true
}

output "ssh_user" {
  description = "SSH username for connecting to the instance"
  value       = "ec2-user"
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.amazon_linux_2.id
}

output "availability_zone" {
  description = "Availability zone where instance is running"
  value       = aws_instance.webapp.availability_zone
}

output "webapp_url" {
  description = "URL to access the web application"
  value       = "http://${aws_eip.webapp_eip.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_eip.webapp_eip.public_ip}"
  sensitive   = true
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "connection_test" {
  description = "Command to test HTTP connection"
  value       = "curl -v http://${aws_eip.webapp_eip.public_ip}"
}

# Grouped output for easy reference
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    instance_id       = aws_instance.webapp.id
    public_ip         = aws_eip.webapp_eip.public_ip
    web_url           = "http://${aws_eip.webapp_eip.public_ip}"
    ssh_user          = "ec2-user"
    region            = var.aws_region
    availability_zone = aws_instance.webapp.availability_zone
  }
}
