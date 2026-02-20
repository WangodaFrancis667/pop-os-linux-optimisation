#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — Common Library                              ║
# ║  Shared functions for TUI, hardware detection, menus, and installation      ║
# ║                                                                              ║
# ║  Source this file in scripts:  source "$(dirname "$0")/../lib/common.sh"    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ─────────────────────────────────────────────────────────────
#  ANSI Color Palette
# ─────────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly NC='\033[0m'

# Pop!_OS brand-inspired palette
readonly TEAL='\033[38;5;43m'
readonly ORANGE='\033[38;5;208m'
readonly LIGHT_BLUE='\033[38;5;75m'
readonly LIGHT_GREEN='\033[38;5;114m'
readonly DARK_GRAY='\033[38;5;240m'

# Background colors
readonly BG_TEAL='\033[48;5;43m'
readonly BG_RED='\033[48;5;196m'
readonly BG_GREEN='\033[48;5;34m'
readonly BG_BLUE='\033[48;5;33m'
readonly BG_DARK='\033[48;5;236m'

# ─────────────────────────────────────────────────────────────
#  Global Configuration
# ─────────────────────────────────────────────────────────────
TOOLKIT_VERSION="2.0.0"
TOOLKIT_NAME="Pop!_OS Optimization Toolkit"
LOG_FILE="/tmp/pop-os-toolkit-$(date +%Y%m%d-%H%M%S).log"
DRY_RUN="${DRY_RUN:-false}"

# ─────────────────────────────────────────────────────────────
#  Terminal Utilities
# ─────────────────────────────────────────────────────────────
term_width() {
    tput cols 2>/dev/null || echo 80
}

term_height() {
    tput lines 2>/dev/null || echo 24
}

clear_screen() {
    printf '\033[2J\033[H'
}

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

# Ensure cursor is shown on exit
trap 'show_cursor' EXIT

# ─────────────────────────────────────────────────────────────
#  Box Drawing & Layout
# ─────────────────────────────────────────────────────────────
draw_line() {
    local width="${1:-$(term_width)}"
    local char="${2:-─}"
    local color="${3:-$TEAL}"
    printf "${color}"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf "${NC}\n"
}

draw_box_top() {
    local width="${1:-60}"
    local color="${2:-$TEAL}"
    printf "${color}╔"
    printf '%*s' "$((width - 2))" '' | tr ' ' '═'
    printf "╗${NC}\n"
}

draw_box_middle() {
    local width="${1:-60}"
    local color="${2:-$TEAL}"
    printf "${color}╠"
    printf '%*s' "$((width - 2))" '' | tr ' ' '═'
    printf "╣${NC}\n"
}

draw_box_bottom() {
    local width="${1:-60}"
    local color="${2:-$TEAL}"
    printf "${color}╚"
    printf '%*s' "$((width - 2))" '' | tr ' ' '═'
    printf "╝${NC}\n"
}

draw_box_line() {
    local text="$1"
    local width="${2:-60}"
    local color="${3:-$TEAL}"
    local text_color="${4:-$WHITE}"

    # Strip ANSI codes for length calculation
    local clean_text
    clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    local padding=$((width - 4 - text_len))

    if [ "$padding" -lt 0 ]; then
        padding=0
    fi

    printf "${color}║${NC} ${text_color}${text}%*s ${color}║${NC}\n" "$padding" ""
}

draw_box_line_centered() {
    local text="$1"
    local width="${2:-60}"
    local color="${3:-$TEAL}"
    local text_color="${4:-$WHITE}"

    local clean_text
    clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    local left_pad=$(( (width - 4 - text_len) / 2 ))
    local right_pad=$(( width - 4 - text_len - left_pad ))

    if [ "$left_pad" -lt 0 ]; then left_pad=0; fi
    if [ "$right_pad" -lt 0 ]; then right_pad=0; fi

    printf "${color}║${NC}%*s${text_color}${text}%*s${color}║${NC}\n" \
        "$((left_pad + 1))" "" "$((right_pad + 1))" ""
}

draw_empty_line() {
    local width="${1:-60}"
    local color="${2:-$TEAL}"
    printf "${color}║${NC}%*s${color}║${NC}\n" "$((width - 2))" ""
}

# ─────────────────────────────────────────────────────────────
#  Logging
# ─────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log_info() {
    local msg="$1"
    echo -e "  ${CYAN}[INFO]${NC}  $msg"
    log "INFO: $msg"
}

log_success() {
    local msg="$1"
    echo -e "  ${GREEN}[  OK ]${NC}  $msg"
    log "OK: $msg"
}

log_warning() {
    local msg="$1"
    echo -e "  ${YELLOW}[WARN]${NC}  $msg"
    log "WARN: $msg"
}

log_error() {
    local msg="$1"
    echo -e "  ${RED}[FAIL]${NC}  $msg"
    log "ERROR: $msg"
}

log_step() {
    local step="$1"
    local total="$2"
    local msg="$3"
    echo -e "  ${TEAL}[${step}/${total}]${NC}  ${BOLD}${msg}${NC}"
    log "STEP ${step}/${total}: $msg"
}

# ─────────────────────────────────────────────────────────────
#  Progress Indicators
# ─────────────────────────────────────────────────────────────
spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    hide_cursor
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${TEAL}${chars:i++%${#chars}:1}${NC}  ${msg}"
        sleep 0.1
    done
    printf "\r  ${GREEN}✓${NC}  ${msg}\n"
    show_cursor
}

progress_bar() {
    local current=$1
    local total=$2
    local width="${3:-40}"
    local label="${4:-Progress}"

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r  ${label}: ${TEAL}["
    printf '%*s' "$filled" '' | tr ' ' '█'
    printf '%*s' "$empty" '' | tr ' ' '░'
    printf "]${NC} ${BOLD}${percent}%%${NC}"

    if [ "$current" -eq "$total" ]; then
        printf "\n"
    fi
}

# ─────────────────────────────────────────────────────────────
#  Hardware Detection
# ─────────────────────────────────────────────────────────────
detect_hostname() {
    hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-Unknown Linux}"
    else
        uname -s
    fi
}

detect_kernel() {
    uname -r
}

detect_laptop_model() {
    local model=""
    if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
        model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
    fi
    if [ -z "$model" ] && command -v dmidecode &>/dev/null; then
        model=$(sudo dmidecode -s system-product-name 2>/dev/null)
    fi
    echo "${model:-Unknown System}"
}

detect_manufacturer() {
    local manufacturer=""
    if [ -f /sys/devices/virtual/dmi/id/sys_vendor ]; then
        manufacturer=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null)
    fi
    echo "${manufacturer:-Unknown}"
}

detect_cpu() {
    local cpu_model
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | awk -F: '{print $2}' | xargs)
    echo "${cpu_model:-Unknown CPU}"
}

detect_cpu_cores() {
    nproc 2>/dev/null || echo "?"
}

detect_cpu_threads() {
    grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?"
}

detect_gpu() {
    if command -v lspci &>/dev/null; then
        lspci 2>/dev/null | grep -i 'vga\|3d\|display' | awk -F: '{print $3}' | xargs
    elif command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null
    else
        echo "Unknown GPU"
    fi
}

detect_gpu_vram() {
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1
    else
        echo "?"
    fi
}

detect_nvidia_driver() {
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1
    else
        echo "Not installed"
    fi
}

detect_cuda_version() {
    if command -v nvcc &>/dev/null; then
        nvcc --version 2>/dev/null | grep "release" | awk '{print $6}' | tr -d ','
    elif [ -f /usr/local/cuda/version.txt ]; then
        cat /usr/local/cuda/version.txt 2>/dev/null | awk '{print $3}'
    else
        echo "Not installed"
    fi
}

detect_ram() {
    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -n "$ram_kb" ]; then
        echo "$((ram_kb / 1024 / 1024)) GB"
    else
        echo "Unknown"
    fi
}

detect_ram_mb() {
    grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}'
}

detect_storage() {
    lsblk -d -o NAME,SIZE,TYPE 2>/dev/null | grep disk | head -5 || echo "Unknown"
}

detect_storage_root() {
    df -h / 2>/dev/null | awk 'NR==2 {print $2 " total, " $4 " free"}'
}

detect_battery() {
    if [ -d /sys/class/power_supply/BAT0 ]; then
        local capacity
        capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "?")
        local status
        status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "?")
        echo "${capacity}% (${status})"
    else
        echo "No battery (Desktop)"
    fi
}

detect_is_laptop() {
    [ -d /sys/class/power_supply/BAT0 ] && echo "true" || echo "false"
}

# Comprehensive system profile
print_system_banner() {
    local width=62
    local model cpu gpu ram storage os_name kernel battery

    model=$(detect_laptop_model)
    cpu=$(detect_cpu)
    gpu=$(detect_gpu)
    ram=$(detect_ram)
    storage=$(detect_storage_root)
    os_name=$(detect_os)
    kernel=$(detect_kernel)
    battery=$(detect_battery)
    local manufacturer
    manufacturer=$(detect_manufacturer)

    echo ""
    draw_box_top $width "$TEAL"
    draw_empty_line $width "$TEAL"
    draw_box_line_centered "Pop!_OS Optimization Toolkit v${TOOLKIT_VERSION}" $width "$TEAL" "${BOLD}${WHITE}"
    draw_box_line_centered "Hardware-Aware Linux Configuration" $width "$TEAL" "${DIM}"
    draw_empty_line $width "$TEAL"
    draw_box_middle $width "$TEAL"
    draw_box_line_centered "SYSTEM PROFILE" $width "$TEAL" "${BOLD}${ORANGE}"
    draw_box_middle $width "$TEAL"
    draw_empty_line $width "$TEAL"
    draw_box_line "  ${CYAN}Machine :${NC}  ${WHITE}${manufacturer} ${model}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}OS      :${NC}  ${WHITE}${os_name}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}Kernel  :${NC}  ${WHITE}${kernel}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}CPU     :${NC}  ${WHITE}${cpu}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}GPU     :${NC}  ${WHITE}${gpu}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}RAM     :${NC}  ${WHITE}${ram}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}Storage :${NC}  ${WHITE}${storage}" $width "$TEAL" "$NC"
    draw_box_line "  ${CYAN}Battery :${NC}  ${WHITE}${battery}" $width "$TEAL" "$NC"
    draw_empty_line $width "$TEAL"
    draw_box_bottom $width "$TEAL"
    echo ""
}

# ─────────────────────────────────────────────────────────────
#  GPU-Based Recommendations
# ─────────────────────────────────────────────────────────────
detect_gpu_tier() {
    local vram
    vram=$(detect_gpu_vram)

    if [ "$vram" = "?" ]; then
        echo "unknown"
        return
    fi

    local vram_gb=$((vram / 1024))

    if [ "$vram_gb" -ge 24 ]; then
        echo "ultra"       # RTX 4090, A6000
    elif [ "$vram_gb" -ge 16 ]; then
        echo "high"        # RTX 4080, A4500
    elif [ "$vram_gb" -ge 8 ]; then
        echo "medium"      # RTX 3070, RTX 4060
    elif [ "$vram_gb" -ge 4 ]; then
        echo "entry"       # RTX A1000, GTX 1650
    else
        echo "minimal"     # Integrated / old GPU
    fi
}

# ─────────────────────────────────────────────────────────────
#  Interactive Menu System
# ─────────────────────────────────────────────────────────────

# Simple numbered menu — returns selected number
# Usage: show_menu "Title" "Option 1" "Option 2" "Option 3"
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local width=58

    echo ""
    draw_line $width "─" "$TEAL"
    echo -e "  ${BOLD}${WHITE}${title}${NC}"
    draw_line $width "─" "$TEAL"
    echo ""

    local i=1
    for opt in "${options[@]}"; do
        echo -e "    ${TEAL}[${WHITE}${i}${TEAL}]${NC}  ${opt}"
        ((i++))
    done
    echo ""
    echo -e "    ${TEAL}[${WHITE}0${TEAL}]${NC}  ${DIM}Back / Exit${NC}"
    echo ""
    draw_line $width "─" "$TEAL"

    local choice
    while true; do
        printf "  ${TEAL}▸${NC} Enter choice: "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "$choice"
            return 0
        fi
        echo -e "  ${RED}Invalid choice. Try again.${NC}"
    done
}

# Checklist menu — lets user toggle items on/off
# Usage: show_checklist "Title" selected_array label_array
# selected_array: array of 0/1 for each item
# label_array: array of label strings
# Returns: updates selected_array in-place
show_checklist() {
    local title="$1"
    local -n _selected=$2
    local -n _labels=$3
    local count=${#_labels[@]}
    local width=58

    while true; do
        clear_screen
        echo ""
        draw_box_top $width "$TEAL"
        draw_box_line_centered "$title" $width "$TEAL" "${BOLD}${WHITE}"
        draw_box_middle $width "$TEAL"
        draw_empty_line $width "$TEAL"

        local i
        for ((i = 0; i < count; i++)); do
            local marker
            if [ "${_selected[$i]}" -eq 1 ]; then
                marker="${GREEN}[x]${NC}"
            else
                marker="${DIM}[ ]${NC}"
            fi
            draw_box_line "  ${marker} ${TEAL}$((i + 1)).${NC} ${_labels[$i]}" $width "$TEAL" "$NC"
        done

        draw_empty_line $width "$TEAL"
        draw_box_middle $width "$TEAL"
        draw_box_line "  ${CYAN}Enter number${NC} to toggle selection" $width "$TEAL" "$NC"
        draw_box_line "  ${CYAN}a${NC} = Select all  ${CYAN}n${NC} = Deselect all" $width "$TEAL" "$NC"
        draw_box_line "  ${GREEN}c${NC} = Confirm     ${RED}q${NC} = Cancel" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_bottom $width "$TEAL"
        echo ""

        local input
        printf "  ${TEAL}▸${NC} Choice: "
        read -r input

        case "$input" in
            [0-9]|[0-9][0-9])
                if [ "$input" -ge 1 ] && [ "$input" -le "$count" ]; then
                    local idx=$((input - 1))
                    if [ "${_selected[$idx]}" -eq 1 ]; then
                        _selected[$idx]=0
                    else
                        _selected[$idx]=1
                    fi
                fi
                ;;
            a|A)
                for ((i = 0; i < count; i++)); do
                    _selected[$i]=1
                done
                ;;
            n|N)
                for ((i = 0; i < count; i++)); do
                    _selected[$i]=0
                done
                ;;
            c|C)
                return 0  # Confirmed
                ;;
            q|Q)
                return 1  # Cancelled
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────
#  Confirmation Prompts
# ─────────────────────────────────────────────────────────────
confirm() {
    local msg="${1:-Continue?}"
    local default="${2:-y}"

    local prompt
    if [[ "$default" =~ ^[Yy] ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    printf "  ${YELLOW}?${NC}  ${msg} ${DIM}${prompt}${NC} "
    local reply
    read -r reply
    reply="${reply:-$default}"

    [[ "$reply" =~ ^[Yy] ]]
}

# ─────────────────────────────────────────────────────────────
#  Installation Helpers
# ─────────────────────────────────────────────────────────────
check_is_popos() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "${ID:-}" == "pop" ]]; then
            return 0
        fi
    fi
    log_warning "This toolkit is designed for Pop!_OS. You appear to be running a different distribution."
    if ! confirm "Continue anyway?"; then
        exit 0
    fi
}

check_internet() {
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log_error "No internet connection detected."
        log_info "Please connect to the internet and try again."
        return 1
    fi
    return 0
}

ensure_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. Some operations may behave differently."
        return 0
    fi

    log_info "Sudo access required. You may be prompted for your password."
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges."
        return 1
    fi

    # Keep sudo alive during script execution
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

apt_install() {
    local packages=("$@")
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would install: ${packages[*]}"
        return 0
    fi
    sudo apt install -y "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
}

pip_install() {
    local packages=("$@")
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would pip install: ${packages[*]}"
        return 0
    fi
    pip3 install --user "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
}

flatpak_install() {
    local packages=("$@")
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would flatpak install: ${packages[*]}"
        return 0
    fi
    flatpak install -y flathub "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
}

snap_install() {
    local packages=("$@")
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would snap install: ${packages[*]}"
        return 0
    fi
    sudo snap install "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
}

command_exists() {
    command -v "$1" &>/dev/null
}

is_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# ─────────────────────────────────────────────────────────────
#  Section Headers
# ─────────────────────────────────────────────────────────────
print_section() {
    local title="$1"
    local icon="${2:-▸}"
    echo ""
    echo -e "  ${TEAL}${icon}${NC}  ${BOLD}${WHITE}${title}${NC}"
    draw_line 58 "─" "$DARK_GRAY"
}

print_subsection() {
    local title="$1"
    echo -e "    ${LIGHT_BLUE}◦${NC}  ${title}"
}

# ─────────────────────────────────────────────────────────────
#  Summary & Completion
# ─────────────────────────────────────────────────────────────
print_completion_banner() {
    local title="${1:-Setup Complete}"
    local width=58
    echo ""
    draw_box_top $width "$GREEN"
    draw_empty_line $width "$GREEN"
    draw_box_line_centered "$title" $width "$GREEN" "${BOLD}${WHITE}"
    draw_empty_line $width "$GREEN"
    draw_box_line "  Log file: ${LOG_FILE}" $width "$GREEN" "${DIM}"
    draw_empty_line $width "$GREEN"
    draw_box_bottom $width "$GREEN"
    echo ""
}

print_error_banner() {
    local title="${1:-An Error Occurred}"
    local width=58
    echo ""
    draw_box_top $width "$RED"
    draw_empty_line $width "$RED"
    draw_box_line_centered "$title" $width "$RED" "${BOLD}${WHITE}"
    draw_empty_line $width "$RED"
    draw_box_line "  Check log: ${LOG_FILE}" $width "$RED" "${DIM}"
    draw_empty_line $width "$RED"
    draw_box_bottom $width "$RED"
    echo ""
}

# ─────────────────────────────────────────────────────────────
#  Script Resolution
# ─────────────────────────────────────────────────────────────
TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TOOLKIT_ROOT
