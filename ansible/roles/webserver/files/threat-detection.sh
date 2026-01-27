#!/bin/bash
# Real-time threat detection monitoring

LOG_FILE="/var/log/webapp/threats.log"
ALERT_EMAIL="admin@example.com"

# ===========================================================================
# Function: Check for unauthorized access attempts
# ===========================================================================
check_unauthorized_access() {
    # Look for repeated failed SSH attempts
    if [ -f /var/log/secure ]; then
        FAILED_ATTEMPTS=$(grep "Failed password" /var/log/secure 2>/dev/null | \
            tail -100 | awk '{print $11}' | sort | uniq -c | sort -rn | head -1)

        if [ -n "$FAILED_ATTEMPTS" ]; then
            COUNT=$(echo "$FAILED_ATTEMPTS" | awk '{print $1}')
            if [ "$COUNT" -gt 5 ]; then
                echo "[$(date)] ALERT: High number of failed login attempts: $COUNT" >> "$LOG_FILE"
            fi
        fi
    fi
}

# ===========================================================================
# Function: Check for suspicious processes
# ===========================================================================
check_suspicious_processes() {
    SUSPICIOUS_PROCS=("nc " "ncat " "nmap " "wget " "curl ")

    for proc in "${SUSPICIOUS_PROCS[@]}"; do
        if pgrep -f "$proc" > /dev/null 2>&1; then
            echo "[$(date)] ALERT: Suspicious process detected: $proc" >> "$LOG_FILE"
        fi
    done
}

# ===========================================================================
# Function: Check for privilege escalation attempts
# ===========================================================================
check_privilege_escalation() {
    # Check sudo logs for unusual activity
    if [ -f /var/log/secure ]; then
        SUDO_ATTEMPTS=$(grep "sudo:" /var/log/secure 2>/dev/null | tail -50)

        if echo "$SUDO_ATTEMPTS" | grep -i "command not found\|no valid\|incorrect password" > /dev/null 2>&1; then
            echo "[$(date)] ALERT: Sudo privilege escalation attempt detected" >> "$LOG_FILE"
        fi
    fi
}

# ===========================================================================
# Function: Monitor network connections
# ===========================================================================
check_network_anomalies() {
    # Check for unusual port usage
    LISTENING_PORTS=$(ss -tlnp 2>/dev/null | grep LISTEN || netstat -tlnp 2>/dev/null | grep LISTEN)

    # Alert on unexpected ports
    EXPECTED_PORTS="22 80 443 5000"

    while read -r line; do
        PORT=$(echo "$line" | awk '{print $4}' | sed 's/.*://' | grep -oE '[0-9]+$')

        if [ -n "$PORT" ]; then
            if ! echo "$EXPECTED_PORTS" | grep -q "$PORT"; then
                echo "[$(date)] ALERT: Unexpected listening port detected: $PORT" >> "$LOG_FILE"
            fi
        fi
    done <<< "$LISTENING_PORTS"
}

# ===========================================================================
# Function: Check system load and resource usage
# ===========================================================================
check_resource_usage() {
    # Get CPU usage
    if command -v top &> /dev/null; then
        CPU_USAGE=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

        CPU_THRESHOLD=80
        if [ -n "$CPU_USAGE" ]; then
            if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
                echo "[$(date)] ALERT: High CPU usage: ${CPU_USAGE}%" >> "$LOG_FILE"
            fi
        fi
    fi

    # Get memory usage
    if command -v free &> /dev/null; then
        MEMORY_USAGE=$(free 2>/dev/null | grep Mem | awk '{printf("%.2f", ($3/$2) * 100.0)}')

        MEMORY_THRESHOLD=85
        if [ -n "$MEMORY_USAGE" ]; then
            if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
                echo "[$(date)] ALERT: High memory usage: ${MEMORY_USAGE}%" >> "$LOG_FILE"
            fi
        fi
    fi
}

# ===========================================================================
# Main execution
# ===========================================================================
main() {
    # Ensure log file exists and is writable
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null
        chmod 640 "$LOG_FILE" 2>/dev/null
    fi

    check_unauthorized_access
    check_suspicious_processes
    check_privilege_escalation
    check_network_anomalies
    check_resource_usage
}

# Run monitoring checks
main
