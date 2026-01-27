# Ansible Security Policies using Open Policy Agent

package ansible.security

# ============================================================================
# POLICY 1: Enforce Become Usage
# ============================================================================

# Tasks modifying system files must use explicit become
deny_implicit_root[msg] {
    task := input.tasks[_]

    # Check if task modifies system files/directories
    contains(task.path, "/etc/") or
    contains(task.path, "/opt/") or
    contains(task.path, "/var/") or
    contains(task.path, "/usr/")

    # But doesn't have explicit become
    not task.become

    msg := sprintf("Task '%s' modifies system files but doesn't use explicit 'become: true'", [task.name])
}

# ============================================================================
# POLICY 2: Block Hardcoded Secrets
# ============================================================================

# Reject tasks with hardcoded passwords/API keys
deny_hardcoded_secrets[msg] {
    task := input.tasks[_]

    # Check vars for common secret patterns
    task.vars[key]

    secret_patterns := [
        "password",
        "api_key", "apikey",
        "secret",
        "token",
        "credential"
    ]

    contains(key, secret_patterns[_])

    msg := sprintf("Task '%s' contains hardcoded secret variable '%s'. Use Ansible Vault instead.", [task.name, key])
}

# ============================================================================
# POLICY 3: Enforce Ansible Vault Usage
# ============================================================================

# Variables containing sensitive data should be from vault
require_vault_for_secrets[msg] {
    task := input.tasks[_]

    # Check for secret-like variable names
    task.vars[key]

    secret_keywords := [
        "password",
        "api_key",
        "secret",
        "token"
    ]

    contains(key, secret_keywords[_])

    # Should reference vault variable (starts with vault_)
    not startswith(task.vars[key], "{{ vault_")

    msg := sprintf("Secret variable '%s' in task '%s' should use Vault. Example: '{{ vault_%s }}'", [key, task.name, key])
}

# ============================================================================
# POLICY 4: Require Checksums for Downloads
# ============================================================================

# Download tasks must specify checksums
deny_unverified_downloads[msg] {
    task := input.tasks[_]

    # get_url, uri, shell with curl/wget
    task.module == "ansible.builtin.get_url" or
    task.module == "community.general.download"

    # But missing checksum
    not task.checksum

    msg := sprintf("Download task '%s' missing 'checksum' verification. Add: checksum: sha256:...", [task.name])
}

# ============================================================================
# POLICY 5: Restrict Privileged Commands
# ============================================================================

# Shell commands shouldn't use privileged operations without become
deny_shell_privilege_escalation[msg] {
    task := input.tasks[_]

    (task.module == "ansible.builtin.shell" or
    task.module == "ansible.builtin.command")

    # Contains sudo or other privilege indicators
    contains(task.args, "sudo")

    # But doesn't use become
    not task.become

    msg := sprintf("Task '%s' uses sudo in command but doesn't use Ansible become. Use 'become: true' instead.", [task.name])
}

# ============================================================================
# POLICY 6: Enforce no_log for Sensitive Data
# ============================================================================

# Tasks that output passwords must use no_log
require_nolog_for_sensitive_output[msg] {
    task := input.tasks[_]

    # Tasks that work with passwords/secrets
    task.vars[key]

    sensitive_keywords := ["password", "api_key", "secret", "token"]
    contains(key, sensitive_keywords[_])

    # Should have no_log: true
    not task.no_log

    msg := sprintf("Task '%s' handles sensitive data. Add 'no_log: true' to prevent credential exposure in logs.", [task.name])
}

# ============================================================================
# POLICY 7: Block Dangerous Modules
# ============================================================================

# Block usage of inherently insecure modules
deny_dangerous_modules[msg] {
    task := input.tasks[_]

    # Dangerous modules
    dangerous_modules := [
        "raw",           # Bypass all module controls
        "script",        # Run arbitrary scripts
        "command"        # With sudo/privileged ops
    ]

    task.module == dangerous_modules[_]

    msg := sprintf("Task '%s' uses dangerous module '%s'. Use safer alternatives.", [task.name, task.module])
}

# ============================================================================
# WARNINGS (Non-blocking)
# ============================================================================

# Warn about tasks without name
warn_unnamed_tasks[msg] {
    task := input.tasks[_]

    not task.name

    msg := sprintf("Task should have descriptive name. Add: name: 'Descriptive name for task'")
}
