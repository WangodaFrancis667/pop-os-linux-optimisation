#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — SSH Configuration                           ║
# ║                                                                              ║
# ║  Interactive SSH key generation, agent setup, GitHub/GitLab integration,     ║
# ║  and optional SSH server hardening.                                          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

SSH_DIR="$HOME/.ssh"

# ─────────────────────────────────────────────────────────────
#  Package Groups
# ─────────────────────────────────────────────────────────────
SSH_LABELS=(
    "Generate SSH Key Pair    (Ed25519 — recommended)"
    "Configure SSH Agent      (Auto-start, keychain)"
    "GitHub SSH Setup         (Add key + test connection)"
    "GitLab SSH Setup         (Add key + test connection)"
    "SSH Client Config        (Host aliases, defaults)"
    "SSH Server (sshd)        (Install & harden OpenSSH server)"
    "Fail2Ban                 (Brute-force protection for sshd)"
)

SSH_SELECTED=(1 1 1 0 1 0 0)

# ─────────────────────────────────────────────────────────────
#  SSH Key Generation
# ─────────────────────────────────────────────────────────────
generate_ssh_key() {
    print_section "SSH Key Generation"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # Choose key type
    local width=58
    echo ""
    echo -e "  ${BOLD}Select key type:${NC}"
    echo -e "    ${TEAL}[1]${NC} Ed25519 ${GREEN}(recommended)${NC} — modern, fast, secure"
    echo -e "    ${TEAL}[2]${NC} RSA 4096 — maximum compatibility"
    echo -e "    ${TEAL}[3]${NC} ECDSA 521 — elliptic curve, good balance"
    echo ""

    local key_type="ed25519"
    local key_bits=""
    printf "  ${TEAL}▸${NC} Choice [1]: "
    local choice
    read -r choice
    case "${choice:-1}" in
        2) key_type="rsa"; key_bits="-b 4096" ;;
        3) key_type="ecdsa"; key_bits="-b 521" ;;
        *) key_type="ed25519" ;;
    esac

    # Get email for key comment
    local email
    local git_email
    git_email=$(git config --global user.email 2>/dev/null || echo "")

    if [ -n "$git_email" ]; then
        printf "  ${TEAL}▸${NC} Email for key [${git_email}]: "
        read -r email
        email="${email:-$git_email}"
    else
        printf "  ${TEAL}▸${NC} Email for key: "
        read -r email
    fi

    if [ -z "$email" ]; then
        email="$(whoami)@$(hostname)"
        log_info "Using default: ${email}"
    fi

    # Key file name
    local key_name="id_${key_type}"
    local key_path="${SSH_DIR}/${key_name}"

    if [ -f "$key_path" ]; then
        log_warning "Key already exists: ${key_path}"
        if ! confirm "Generate a new key? (existing key will be backed up)"; then
            return 0
        fi
        cp "$key_path" "${key_path}.backup.$(date +%Y%m%d%H%M%S)"
        cp "${key_path}.pub" "${key_path}.pub.backup.$(date +%Y%m%d%H%M%S)"
        log_info "Existing keys backed up."
    fi

    # Generate key
    echo ""
    log_info "Generating ${key_type} key..."
    echo -e "  ${DIM}You'll be prompted for a passphrase (recommended for security).${NC}"
    echo ""

    # shellcheck disable=SC2086
    ssh-keygen -t "$key_type" $key_bits -C "$email" -f "$key_path"

    # Set permissions
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"

    echo ""
    log_success "SSH key generated: ${key_path}"
    echo ""
    echo -e "  ${BOLD}Public key:${NC}"
    echo -e "  ${DIM}$(cat "${key_path}.pub")${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
#  SSH Agent Configuration
# ─────────────────────────────────────────────────────────────
configure_ssh_agent() {
    print_section "SSH Agent Configuration"

    local shell_rc="$HOME/.bashrc"

    # Install keychain for persistent agent
    apt_install keychain 2>/dev/null || log_info "keychain not available, using ssh-agent."

    if command_exists keychain; then
        # Configure keychain in bashrc
        local keychain_block='# SSH Agent (keychain)
eval $(keychain --eval --agents ssh --quiet)'

        if ! grep -q "keychain" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "$keychain_block" >> "$shell_rc"
            log_info "Added keychain config to ${shell_rc}"
        fi

        # Add existing keys to keychain config
        local keys=""
        for key in "$SSH_DIR"/id_*; do
            if [[ "$key" != *.pub ]] && [[ "$key" != *.backup* ]]; then
                keys="$keys $(basename "$key")"
            fi
        done

        if [ -n "$keys" ]; then
            # Update keychain line with key names
            local keychain_line="eval \$(keychain --eval --agents ssh --quiet${keys})"
            sed -i "s|eval \$(keychain.*|${keychain_line}|" "$shell_rc" 2>/dev/null || true
        fi

        log_success "Keychain configured for automatic key loading."
    else
        # Fallback: basic ssh-agent auto-start
        local agent_block='# SSH Agent auto-start
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
fi'

        if ! grep -q "SSH_AUTH_SOCK" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "$agent_block" >> "$shell_rc"
        fi

        # Add keys to agent
        for key in "$SSH_DIR"/id_*; do
            if [[ "$key" != *.pub ]] && [[ "$key" != *.backup* ]]; then
                ssh-add "$key" 2>/dev/null || true
            fi
        done

        log_success "SSH agent auto-start configured."
    fi
}

# ─────────────────────────────────────────────────────────────
#  GitHub SSH Setup
# ─────────────────────────────────────────────────────────────
setup_github_ssh() {
    print_section "GitHub SSH Integration"

    # Find the public key
    local pub_key=""
    for key_file in "$SSH_DIR"/id_ed25519.pub "$SSH_DIR"/id_rsa.pub "$SSH_DIR"/id_ecdsa.pub; do
        if [ -f "$key_file" ]; then
            pub_key="$key_file"
            break
        fi
    done

    if [ -z "$pub_key" ]; then
        log_error "No SSH public key found. Generate one first."
        return 1
    fi

    echo ""
    echo -e "  ${BOLD}Your public key (copy this):${NC}"
    echo ""
    draw_line 58 "─" "$DARK_GRAY"
    cat "$pub_key"
    draw_line 58 "─" "$DARK_GRAY"
    echo ""

    # Copy to clipboard if possible
    if command_exists xclip; then
        cat "$pub_key" | xclip -selection clipboard
        log_success "Key copied to clipboard!"
    elif command_exists xsel; then
        cat "$pub_key" | xsel --clipboard
        log_success "Key copied to clipboard!"
    elif command_exists wl-copy; then
        cat "$pub_key" | wl-copy
        log_success "Key copied to clipboard!"
    else
        log_info "Install xclip for automatic clipboard copy: sudo apt install xclip"
    fi

    echo -e "  ${BOLD}Steps to add to GitHub:${NC}"
    echo -e "    ${TEAL}1.${NC} Go to ${UNDERLINE}https://github.com/settings/keys${NC}"
    echo -e "    ${TEAL}2.${NC} Click '${BOLD}New SSH key${NC}'"
    echo -e "    ${TEAL}3.${NC} Paste the key above"
    echo -e "    ${TEAL}4.${NC} Give it a title (e.g., '$(hostname)')"
    echo ""

    # Try GitHub CLI if available
    if command_exists gh; then
        if confirm "Use GitHub CLI to add key automatically?"; then
            local key_title
            printf "  ${TEAL}▸${NC} Key title [$(hostname)]: "
            read -r key_title
            key_title="${key_title:-$(hostname)}"

            gh ssh-key add "$pub_key" --title "$key_title" && \
                log_success "Key added to GitHub via CLI." || \
                log_warning "Failed. You may need to run 'gh auth login' first."
        fi
    fi

    # Add GitHub to SSH config
    ensure_ssh_config_host "github.com" "github.com" "git" "$(basename "$pub_key" .pub)"

    # Test connection
    echo ""
    if confirm "Test GitHub SSH connection?"; then
        echo ""
        ssh -T git@github.com 2>&1 || true
        echo ""
    fi
}

# ─────────────────────────────────────────────────────────────
#  GitLab SSH Setup
# ─────────────────────────────────────────────────────────────
setup_gitlab_ssh() {
    print_section "GitLab SSH Integration"

    local pub_key=""
    for key_file in "$SSH_DIR"/id_ed25519.pub "$SSH_DIR"/id_rsa.pub "$SSH_DIR"/id_ecdsa.pub; do
        if [ -f "$key_file" ]; then
            pub_key="$key_file"
            break
        fi
    done

    if [ -z "$pub_key" ]; then
        log_error "No SSH public key found. Generate one first."
        return 1
    fi

    echo ""
    echo -e "  ${BOLD}Steps to add to GitLab:${NC}"
    echo -e "    ${TEAL}1.${NC} Go to ${UNDERLINE}https://gitlab.com/-/user_settings/ssh_keys${NC}"
    echo -e "    ${TEAL}2.${NC} Click '${BOLD}Add new key${NC}'"
    echo -e "    ${TEAL}3.${NC} Paste your public key"
    echo ""

    echo -e "  ${BOLD}Your public key:${NC}"
    draw_line 58 "─" "$DARK_GRAY"
    cat "$pub_key"
    draw_line 58 "─" "$DARK_GRAY"
    echo ""

    # Add GitLab to SSH config
    ensure_ssh_config_host "gitlab.com" "gitlab.com" "git" "$(basename "$pub_key" .pub)"

    # Test connection
    if confirm "Test GitLab SSH connection?"; then
        echo ""
        ssh -T git@gitlab.com 2>&1 || true
        echo ""
    fi
}

# ─────────────────────────────────────────────────────────────
#  SSH Client Config
# ─────────────────────────────────────────────────────────────
ensure_ssh_config_host() {
    local host_alias="$1"
    local hostname="$2"
    local user="$3"
    local identity="$4"

    local config_file="$SSH_DIR/config"

    # Create config file if it doesn't exist
    if [ ! -f "$config_file" ]; then
        touch "$config_file"
        chmod 600 "$config_file"
    fi

    # Check if host already configured
    if grep -q "Host ${host_alias}" "$config_file" 2>/dev/null; then
        log_info "SSH config for '${host_alias}' already exists."
        return 0
    fi

    cat >> "$config_file" << EOF

# ${host_alias}
Host ${host_alias}
    HostName ${hostname}
    User ${user}
    IdentityFile ~/.ssh/${identity}
    IdentitiesOnly yes
EOF

    log_info "Added SSH config for ${host_alias}."
}

configure_ssh_client() {
    print_section "SSH Client Configuration"

    local config_file="$SSH_DIR/config"

    # Create base config with secure defaults
    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        cat > "$config_file" << 'SSHCFG'
# ─────────────────────────────────────────────────────────
#  SSH Client Configuration
#  Generated by Pop!_OS Optimization Toolkit
# ─────────────────────────────────────────────────────────

# Global defaults
Host *
    # Security
    AddKeysToAgent yes
    IdentitiesOnly yes

    # Connection
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectionAttempts 3

    # Multiplexing (reuse connections)
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

    # Preferred authentication
    PreferredAuthentications publickey,keyboard-interactive,password

    # Disable host key checking for local network (optional)
    # Host 192.168.*.*
    #     StrictHostKeyChecking no
    #     UserKnownHostsFile /dev/null
SSHCFG
        chmod 600 "$config_file"
        log_info "Created SSH client config with secure defaults."
    else
        log_info "SSH client config already exists."
    fi

    # Create sockets directory for multiplexing
    mkdir -p "$SSH_DIR/sockets"

    # Offer to add custom hosts
    echo ""
    if confirm "Add a custom SSH host?"; then
        while true; do
            echo ""
            local alias_name hostname port user identity

            printf "  ${TEAL}▸${NC} Host alias (e.g., 'myserver'): "
            read -r alias_name
            [ -z "$alias_name" ] && break

            printf "  ${TEAL}▸${NC} Hostname/IP: "
            read -r hostname
            [ -z "$hostname" ] && break

            printf "  ${TEAL}▸${NC} Port [22]: "
            read -r port
            port="${port:-22}"

            printf "  ${TEAL}▸${NC} User [$(whoami)]: "
            read -r user
            user="${user:-$(whoami)}"

            printf "  ${TEAL}▸${NC} Identity file [id_ed25519]: "
            read -r identity
            identity="${identity:-id_ed25519}"

            cat >> "$config_file" << EOF

# ${alias_name}
Host ${alias_name}
    HostName ${hostname}
    Port ${port}
    User ${user}
    IdentityFile ~/.ssh/${identity}
    IdentitiesOnly yes
EOF

            log_success "Added host: ${alias_name} → ${user}@${hostname}:${port}"

            if ! confirm "Add another host?"; then
                break
            fi
        done
    fi

    log_success "SSH client configuration complete."
    echo -e "  ${DIM}Config at: ${config_file}${NC}"
}

# ─────────────────────────────────────────────────────────────
#  SSH Server (sshd) Setup & Hardening
# ─────────────────────────────────────────────────────────────
setup_ssh_server() {
    print_section "SSH Server (sshd) — Install & Harden"

    local width=58
    echo ""
    draw_box_top $width "$YELLOW"
    draw_box_line_centered "SSH Server Configuration" $width "$YELLOW" "${BOLD}${WHITE}"
    draw_box_middle $width "$YELLOW"
    draw_box_line "  This installs OpenSSH server and applies" $width "$YELLOW" "$NC"
    draw_box_line "  security hardening to the configuration." $width "$YELLOW" "$NC"
    draw_empty_line $width "$YELLOW"
    draw_box_line "  ${BOLD}Changes:${NC}" $width "$YELLOW" "$NC"
    draw_box_line "    - Disable root login" $width "$YELLOW" "$NC"
    draw_box_line "    - Disable password authentication" $width "$YELLOW" "$NC"
    draw_box_line "    - Enable key-based auth only" $width "$YELLOW" "$NC"
    draw_box_line "    - Set max authentication attempts" $width "$YELLOW" "$NC"
    draw_box_line "    - Change default port (optional)" $width "$YELLOW" "$NC"
    draw_empty_line $width "$YELLOW"
    draw_box_bottom $width "$YELLOW"
    echo ""

    if ! confirm "Install and configure SSH server?"; then
        return 0
    fi

    # Install OpenSSH server
    apt_install openssh-server

    # Backup original config
    local sshd_config="/etc/ssh/sshd_config"
    if [ ! -f "${sshd_config}.original" ]; then
        sudo cp "$sshd_config" "${sshd_config}.original"
        log_info "Original sshd_config backed up."
    fi

    # Custom port
    local ssh_port="22"
    if confirm "Change SSH port from default 22? (recommended for security)"; then
        printf "  ${TEAL}▸${NC} New SSH port [2222]: "
        read -r ssh_port
        ssh_port="${ssh_port:-2222}"
    fi

    # Create hardened config drop-in
    sudo mkdir -p /etc/ssh/sshd_config.d

    sudo tee /etc/ssh/sshd_config.d/99-hardened.conf > /dev/null << EOF
# ─────────────────────────────────────────────────────────
#  Hardened SSH Server Configuration
#  Generated by Pop!_OS Optimization Toolkit
#  $(date '+%Y-%m-%d %H:%M:%S')
# ─────────────────────────────────────────────────────────

# Network
Port ${ssh_port}
AddressFamily inet
ListenAddress 0.0.0.0

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30

# Security
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Idle timeout
ClientAliveInterval 300
ClientAliveCountMax 2

# Allowed users (uncomment and set your username)
# AllowUsers $(whoami)
EOF

    log_success "Hardened SSH server configuration created."

    # Ensure authorized_keys has the user's key
    local auth_keys="$SSH_DIR/authorized_keys"
    if [ ! -f "$auth_keys" ]; then
        touch "$auth_keys"
        chmod 600 "$auth_keys"
        # Add own public key
        for pub in "$SSH_DIR"/id_*.pub; do
            if [ -f "$pub" ]; then
                cat "$pub" >> "$auth_keys"
                log_info "Added $(basename "$pub") to authorized_keys."
            fi
        done
    fi

    # Restart sshd
    sudo systemctl enable ssh
    sudo systemctl restart ssh

    log_success "SSH server running on port ${ssh_port}."

    if [ "$ssh_port" != "22" ]; then
        echo ""
        echo -e "  ${YELLOW}IMPORTANT:${NC} SSH is now on port ${BOLD}${ssh_port}${NC}."
        echo -e "  ${DIM}Connect with: ssh -p ${ssh_port} $(whoami)@$(hostname -I | awk '{print $1}')${NC}"
    fi
}

# ─────────────────────────────────────────────────────────────
#  Fail2Ban
# ─────────────────────────────────────────────────────────────
setup_fail2ban() {
    print_section "Fail2Ban — Brute Force Protection"

    apt_install fail2ban

    # Create local config
    if [ ! -f /etc/fail2ban/jail.local ]; then
        sudo tee /etc/fail2ban/jail.local > /dev/null << 'F2BCFG'
# ─────────────────────────────────────────────────────────
#  Fail2Ban Configuration
#  Generated by Pop!_OS Optimization Toolkit
# ─────────────────────────────────────────────────────────

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

# Email notifications (configure sendmail first)
# destemail = your@email.com
# action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
F2BCFG
    fi

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban

    log_success "Fail2Ban configured and running."
    echo -e "  ${DIM}Check status: sudo fail2ban-client status sshd${NC}"
    echo -e "  ${DIM}Banned IPs:   sudo fail2ban-client status sshd | grep 'Banned IP'${NC}"
}

# ─────────────────────────────────────────────────────────────
#  Installer Dispatch
# ─────────────────────────────────────────────────────────────
SSH_FUNCTIONS=(
    generate_ssh_key
    configure_ssh_agent
    setup_github_ssh
    setup_gitlab_ssh
    configure_ssh_client
    setup_ssh_server
    setup_fail2ban
)

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${WHITE}SSH Configuration${NC}"
    echo -e "  ${DIM}Generate keys, configure agent, and set up remote access.${NC}"
    echo ""

    # Show existing SSH status
    log_info "Current SSH status:"
    if [ -d "$SSH_DIR" ]; then
        local key_count
        key_count=$(find "$SSH_DIR" -name "id_*" -not -name "*.pub" -not -name "*.backup*" 2>/dev/null | wc -l)
        echo -e "  ${CYAN}Keys:${NC}   ${key_count} private key(s) found"

        for key in "$SSH_DIR"/id_*.pub; do
            if [ -f "$key" ]; then
                local key_type
                key_type=$(awk '{print $1}' "$key" | sed 's/ssh-//')
                echo -e "    ${DIM}$(basename "$key" .pub) (${key_type})${NC}"
            fi
        done

        [ -f "$SSH_DIR/config" ] && echo -e "  ${CYAN}Config:${NC} exists" || echo -e "  ${CYAN}Config:${NC} not found"
    else
        echo -e "  ${YELLOW}No ~/.ssh directory found — starting fresh.${NC}"
    fi

    if systemctl is-active --quiet ssh 2>/dev/null; then
        echo -e "  ${CYAN}Server:${NC} running"
    else
        echo -e "  ${CYAN}Server:${NC} not running"
    fi
    echo ""

    # Checklist
    if ! show_checklist "SSH Configuration — Select Tasks" SSH_SELECTED SSH_LABELS; then
        log_info "Cancelled."
        return 0
    fi

    local count=0
    for s in "${SSH_SELECTED[@]}"; do ((count += s)); done

    if [ "$count" -eq 0 ]; then
        log_warning "No tasks selected."
        return 0
    fi

    echo ""
    log_info "${count} task(s) selected."
    if ! confirm "Proceed?"; then
        return 0
    fi

    # Some operations need sudo
    local needs_sudo=false
    [[ "${SSH_SELECTED[5]}" -eq 1 || "${SSH_SELECTED[6]}" -eq 1 ]] && needs_sudo=true
    [ "$needs_sudo" = true ] && ensure_sudo

    local total=$count current=0
    for i in "${!SSH_SELECTED[@]}"; do
        if [ "${SSH_SELECTED[$i]}" -eq 1 ]; then
            ((current++))
            echo ""
            log_step "$current" "$total" "${SSH_LABELS[$i]%%(*}"
            ${SSH_FUNCTIONS[$i]}
            progress_bar "$current" "$total" 40 "  Overall"
        fi
    done

    print_completion_banner "SSH Configuration Complete"

    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

main "$@"
