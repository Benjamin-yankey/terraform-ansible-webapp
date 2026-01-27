variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1)"
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "terraform-ansible-webapp"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 50
    error_message = "Project name must be between 1 and 50 characters"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = can(regex("^t[2-3]\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "Instance type must be a valid t2 or t3 instance"
  }
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB"
  }
}

variable "ssh_allowed_ips" {
  description = "List of IP addresses allowed to SSH (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for ip in var.ssh_allowed_ips : can(cidrhost(ip, 0))
    ])
    error_message = "All IPs must be in valid CIDR notation (e.g., 1.2.3.4/32)"
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instance"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable EBS encryption for volumes"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for EC2 instance"
  type        = bool
  default     = true
}
