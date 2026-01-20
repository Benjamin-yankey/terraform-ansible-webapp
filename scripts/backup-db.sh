#!/bin/bash
# Backup database from EC2 instance

set -e

BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
IP=$(cd terraform && terraform output -raw public_ip 2>/dev/null || cat ../evidence/public_ip.txt)

mkdir -p "$BACKUP_DIR"

echo "Backing up database from $IP..."

scp -i ansible/ssh-key.pem \
    ec2-user@$IP:/opt/taskmanager/backend/instance/tasks.db \
    "$BACKUP_DIR/tasks_${TIMESTAMP}.db"

echo "✓ Backup saved to: $BACKUP_DIR/tasks_${TIMESTAMP}.db"

# Keep only last 5 backups
ls -t "$BACKUP_DIR"/tasks_*.db | tail -n +6 | xargs -r rm

echo "✓ Old backups cleaned up"
