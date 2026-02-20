#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — Developer Tools Setup                       ║
# ║                                                                              ║
# ║  Interactive installer for development environment packages.                 ║
# ║  Detects existing tools and lets you choose what to install.                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ─────────────────────────────────────────────────────────────
#  Package Groups
# ─────────────────────────────────────────────────────────────

# Labels for the checklist
DEV_LABELS=(
    "Core Build Tools       (gcc, make, cmake, pkg-config)"
    "Git & Version Control  (git, git-lfs, gh CLI)"
    "Python Development     (python3, pip, venv, dev headers)"
    "Node.js & npm          (via NodeSource LTS)"
    "Rust Toolchain         (rustup, cargo, rustc)"
    "Go Language            (golang from official PPA)"
    "Docker & Compose       (Docker Engine + Compose plugin)"
    "Terminal Utilities     (tmux, htop, btop, neovim, ripgrep)"
    "GUI Editors            (VS Code via Flatpak)"
    "Database Tools         (PostgreSQL client, SQLite, Redis tools)"
    "Python Data Science    (numpy, pandas, matplotlib, jupyter)"
    "CustomTkinter Stack    (customtkinter, pillow, tkinter)"
)

# Default selections (1 = selected, 0 = not selected)
DEV_SELECTED=(1 1 1 1 0 0 1 1 0 0 1 1)

# ─────────────────────────────────────────────────────────────
#  Installation Functions
# ─────────────────────────────────────────────────────────────

install_core_build_tools() {
    print_section "Core Build Tools"
    apt_install git curl wget build-essential cmake pkg-config \
        autoconf automake libtool software-properties-common \
        ca-certificates gnupg lsb-release unzip zip jq
    log_success "Core build tools installed."
}

install_git_tools() {
    print_section "Git & Version Control"
    apt_install git git-lfs

    # Install GitHub CLI
    if ! command_exists gh; then
        log_info "Installing GitHub CLI..."
        (type -p wget >/dev/null || sudo apt install -y wget) \
            && sudo mkdir -p -m 755 /etc/apt/keyrings \
            && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
            && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
            && sudo apt update \
            && sudo apt install -y gh
    else
        log_info "GitHub CLI already installed."
    fi

    # Configure git-lfs
    git lfs install 2>/dev/null || true

    log_success "Git tools installed."
}

install_python_dev() {
    print_section "Python Development"
    apt_install python3 python3-pip python3-venv python3-dev \
        python3-setuptools python3-wheel

    # Upgrade pip
    python3 -m pip install --user --upgrade pip 2>/dev/null || true

    log_success "Python development environment installed."
}

install_nodejs() {
    print_section "Node.js & npm"
    if ! command_exists node; then
        log_info "Installing Node.js LTS via NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        apt_install nodejs
    else
        log_info "Node.js already installed: $(node --version)"
    fi
    log_success "Node.js & npm installed."
}

install_rust() {
    print_section "Rust Toolchain"
    if ! command_exists rustc; then
        log_info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env" 2>/dev/null || true
    else
        log_info "Rust already installed: $(rustc --version)"
    fi
    log_success "Rust toolchain installed."
}

install_go() {
    print_section "Go Language"
    if ! command_exists go; then
        log_info "Installing Go..."
        sudo add-apt-repository -y ppa:longsleep/golang-backports 2>/dev/null || true
        sudo apt update
        apt_install golang-go
    else
        log_info "Go already installed: $(go version)"
    fi
    log_success "Go language installed."
}

install_docker() {
    print_section "Docker & Compose"
    if ! command_exists docker; then
        log_info "Installing Docker Engine..."

        # Add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Set up the repository (Pop!_OS is Ubuntu-based)
        local codename="jammy"
        if [ -f /etc/os-release ]; then
            codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-jammy}")
        fi
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
            https://download.docker.com/linux/ubuntu ${codename} stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        apt_install docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin

        # Add user to docker group
        sudo usermod -aG docker "$USER"
        log_warning "Log out and back in for Docker group membership to take effect."
    else
        log_info "Docker already installed: $(docker --version)"
    fi
    log_success "Docker & Compose installed."
}

install_terminal_utils() {
    print_section "Terminal Utilities"
    apt_install tmux htop neovim ripgrep fd-find bat fzf tree \
        ncdu tldr net-tools dnsutils

    # Install btop if not present
    if ! command_exists btop; then
        apt_install btop 2>/dev/null || log_warning "btop not available in repos, skipping."
    fi

    log_success "Terminal utilities installed."
}

install_gui_editors() {
    print_section "GUI Editors"
    if command_exists flatpak; then
        log_info "Installing VS Code via Flatpak..."
        flatpak_install com.visualstudio.code
    else
        log_info "Installing VS Code via apt..."
        if ! command_exists code; then
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
                https://packages.microsoft.com/repos/code stable main" \
                | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
            sudo apt update
            apt_install code
        else
            log_info "VS Code already installed."
        fi
    fi
    log_success "GUI editors installed."
}

install_database_tools() {
    print_section "Database Tools"
    apt_install postgresql-client sqlite3 libsqlite3-dev redis-tools
    log_success "Database tools installed."
}

install_python_datascience() {
    print_section "Python Data Science Stack"
    pip_install numpy pandas matplotlib seaborn jupyterlab ipykernel \
        scipy scikit-learn
    log_success "Python data science stack installed."
}

install_customtkinter() {
    print_section "CustomTkinter UI Stack"
    apt_install python3-tk
    pip_install customtkinter pillow ttkbootstrap
    log_success "CustomTkinter stack installed."
}

# ─────────────────────────────────────────────────────────────
#  Installer Dispatch
# ─────────────────────────────────────────────────────────────
INSTALL_FUNCTIONS=(
    install_core_build_tools
    install_git_tools
    install_python_dev
    install_nodejs
    install_rust
    install_go
    install_docker
    install_terminal_utils
    install_gui_editors
    install_database_tools
    install_python_datascience
    install_customtkinter
)

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${WHITE}Developer Tools Setup${NC}"
    echo -e "  ${DIM}Select packages to install for your development environment.${NC}"
    echo ""

    # Detect what's already installed
    log_info "Scanning for existing installations..."

    local already=""
    command_exists gcc    && already="${already}  gcc " || true
    command_exists git    && already="${already}  git " || true
    command_exists python3 && already="${already}  python3 " || true
    command_exists node   && already="${already}  node " || true
    command_exists rustc  && already="${already}  rustc " || true
    command_exists go     && already="${already}  go " || true
    command_exists docker && already="${already}  docker " || true
    command_exists nvim   && already="${already}  nvim " || true

    if [ -n "$already" ]; then
        echo -e "  ${GREEN}Already installed:${NC}${DIM}${already}${NC}"
        echo ""
    fi

    # Show checklist
    if ! show_checklist "Developer Tools — Select Packages" DEV_SELECTED DEV_LABELS; then
        log_info "Cancelled by user."
        return 0
    fi

    # Count selected
    local count=0
    for s in "${DEV_SELECTED[@]}"; do
        ((count += s))
    done

    if [ "$count" -eq 0 ]; then
        log_warning "No packages selected."
        return 0
    fi

    # Confirm
    echo ""
    log_info "${count} package group(s) selected for installation."
    if ! confirm "Proceed with installation?"; then
        log_info "Cancelled."
        return 0
    fi

    # Ensure prerequisites
    ensure_sudo
    check_internet || return 1

    # Update package lists
    print_section "Updating Package Lists" "↻"
    sudo apt update 2>&1 | tee -a "$LOG_FILE"

    # Install selected packages
    local total=$count
    local current=0
    for i in "${!DEV_SELECTED[@]}"; do
        if [ "${DEV_SELECTED[$i]}" -eq 1 ]; then
            ((current++))
            echo ""
            log_step "$current" "$total" "Installing: ${DEV_LABELS[$i]%%(*}"
            ${INSTALL_FUNCTIONS[$i]}
            progress_bar "$current" "$total" 40 "  Overall"
        fi
    done

    print_completion_banner "Developer Tools Installation Complete"

    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

main "$@"
