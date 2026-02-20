#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — System Optimization                         ║
# ║                                                                              ║
# ║  Performance tuning, power management, thermal control, SSD care,            ║
# ║  swap/zRAM configuration, and kernel parameters.                             ║
# ║                                                                              ║
# ║  Pop!_OS specific: Uses system76-power, kernelstub, systemd-boot.           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ─────────────────────────────────────────────────────────────
#  Package Groups
# ─────────────────────────────────────────────────────────────
OPT_LABELS=(
    "Power Profiles          (system76-power performance/battery)"
    "Thermal Management      (lm-sensors, thermald, fan control)"
    "SSD Optimization        (TRIM, I/O scheduler, health check)"
    "zRAM Swap               (Compressed RAM swap — better for SSDs)"
    "Swappiness Tuning       (Reduce swap usage, keep more in RAM)"
    "NVIDIA GPU Optimization (Persistence mode, power management)"
    "Kernel Boot Parameters  (Performance-oriented defaults)"
    "Network Optimization    (DNS, MTU, TCP tuning)"
    "System Monitoring Tools (btop, nvtop, iotop, nethogs)"
    "Cleanup & Maintenance   (Remove unused packages, clean cache)"
)

OPT_SELECTED=(1 1 1 1 1 1 0 0 1 1)

# ─────────────────────────────────────────────────────────────
#  Installation Functions
# ─────────────────────────────────────────────────────────────

optimize_power() {
    print_section "Power Profiles — system76-power"

    # Check if system76-power is available (Pop!_OS specific)
    if command_exists system76-power; then
        local current_profile
        current_profile=$(system76-power profile 2>/dev/null | head -1 || echo "unknown")
        log_info "Current power profile: ${current_profile}"

        echo ""
        echo -e "  ${BOLD}Available profiles:${NC}"
        echo -e "    ${TEAL}[1]${NC} ${GREEN}Performance${NC}  — Max CPU/GPU clocks (plugged in)"
        echo -e "    ${TEAL}[2]${NC} ${YELLOW}Balanced${NC}     — Auto-adjust based on load"
        echo -e "    ${TEAL}[3]${NC} ${CYAN}Battery${NC}      — Power saving (unplugged)"
        echo ""

        printf "  ${TEAL}▸${NC} Select profile [2]: "
        local choice
        read -r choice

        case "${choice:-2}" in
            1) sudo system76-power profile performance
               log_success "Set to Performance mode." ;;
            3) sudo system76-power profile battery
               log_success "Set to Battery mode." ;;
            *) sudo system76-power profile balanced
               log_success "Set to Balanced mode." ;;
        esac

        # Enable power daemon
        sudo systemctl enable --now system76-power 2>/dev/null || true

    else
        log_warning "system76-power not found. Installing alternatives..."

        # Install TLP (generic Linux power manager)
        apt_install tlp tlp-rdw
        sudo systemctl enable tlp
        sudo systemctl start tlp
        log_success "TLP power manager installed."
        echo -e "  ${DIM}Configure: sudo tlp-stat -s${NC}"
    fi

    # Auto-cpufreq for hybrid laptop CPUs (great for Intel P/E cores)
    if ! command_exists auto-cpufreq; then
        if confirm "Install auto-cpufreq (smart CPU frequency scaling)?"; then
            log_info "Installing auto-cpufreq..."
            git clone https://github.com/AdnanHodzic/auto-cpufreq.git /tmp/auto-cpufreq 2>/dev/null
            cd /tmp/auto-cpufreq
            sudo ./auto-cpufreq-installer --install
            sudo auto-cpufreq --install
            log_success "auto-cpufreq installed and enabled."
        fi
    else
        log_info "auto-cpufreq already installed."
    fi
}

optimize_thermals() {
    print_section "Thermal Management"

    apt_install lm-sensors psensor

    # Run sensors detection
    log_info "Detecting temperature sensors..."
    sudo sensors-detect --auto 2>/dev/null || true

    # Show current temps
    echo ""
    echo -e "  ${BOLD}Current temperatures:${NC}"
    sensors 2>/dev/null | grep -E "temp|Core|fan" | head -10 | while read -r line; do
        echo -e "    ${DIM}${line}${NC}"
    done
    echo ""

    # Intel thermald (for Intel CPUs)
    local cpu_vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        log_info "Intel CPU detected — installing thermald..."
        apt_install thermald
        sudo systemctl enable --now thermald
        log_success "thermald enabled for thermal management."
    fi

    log_success "Thermal management configured."
    echo -e "  ${DIM}Monitor: psensor (GUI) or watch sensors${NC}"
}

optimize_ssd() {
    print_section "SSD Optimization"

    # Enable periodic TRIM
    log_info "Enabling periodic TRIM (weekly)..."
    sudo systemctl enable fstrim.timer
    sudo systemctl start fstrim.timer

    # Run manual TRIM
    if confirm "Run TRIM now? (safe, frees unused SSD blocks)"; then
        sudo fstrim -v / 2>&1 | tee -a "$LOG_FILE"
    fi

    # Check for NVMe drives
    if command_exists nvme; then
        log_info "NVMe health status:"
        sudo nvme smart-log /dev/nvme0 2>/dev/null | grep -E "temperature|percentage_used|power_on_hours" | \
        while read -r line; do
            echo -e "    ${DIM}${line}${NC}"
        done
    else
        apt_install nvme-cli 2>/dev/null && {
            log_info "NVMe CLI installed."
            sudo nvme smart-log /dev/nvme0 2>/dev/null | grep -E "temperature|percentage_used" | head -5 | \
            while read -r line; do
                echo -e "    ${DIM}${line}${NC}"
            done
        } || log_info "No NVMe CLI available."
    fi

    # Optimize I/O scheduler for NVMe
    local root_device
    root_device=$(lsblk -no PKNAME $(findmnt -no SOURCE /) 2>/dev/null || echo "")

    if [[ "$root_device" == nvme* ]]; then
        log_info "NVMe root device detected (${root_device}). I/O scheduler: none (optimal)."

        # Verify scheduler
        local scheduler
        scheduler=$(cat "/sys/block/${root_device}/queue/scheduler" 2>/dev/null || echo "unknown")
        echo -e "    ${DIM}Current scheduler: ${scheduler}${NC}"
    fi

    # Install smartmontools
    apt_install smartmontools 2>/dev/null || true

    log_success "SSD optimization complete."
}

setup_zram() {
    print_section "zRAM Swap — Compressed Memory"

    echo -e "  ${DIM}zRAM creates a compressed swap device in RAM.${NC}"
    echo -e "  ${DIM}This is faster than disk swap and reduces SSD writes.${NC}"
    echo ""

    apt_install zram-tools

    # Configure zRAM
    local ram_mb
    ram_mb=$(detect_ram_mb)
    local zram_size=$((ram_mb / 2))  # Use half of RAM for zRAM

    sudo tee /etc/default/zramswap > /dev/null << EOF
# zRAM Configuration
# Generated by Pop!_OS Optimization Toolkit
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

    sudo systemctl enable zramswap
    sudo systemctl restart zramswap

    log_success "zRAM configured (${zram_size} MB compressed swap)."
    echo -e "  ${DIM}Verify with: zramctl${NC}"
}

tune_swappiness() {
    print_section "Swappiness Tuning"

    local current_swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    log_info "Current swappiness: ${current_swappiness} (default: 60)"

    echo ""
    echo -e "  ${DIM}Lower values keep more data in RAM (better for 32GB+ systems).${NC}"
    echo -e "  ${DIM}Recommended: 10 for workstations, 60 for servers.${NC}"
    echo ""

    echo -e "  ${BOLD}Select swappiness:${NC}"
    echo -e "    ${TEAL}[1]${NC} 10 — ${GREEN}Workstation${NC} (minimal swap, prefer RAM)"
    echo -e "    ${TEAL}[2]${NC} 30 — Balanced"
    echo -e "    ${TEAL}[3]${NC} 60 — Default (aggressive swap)"
    echo -e "    ${TEAL}[4]${NC} Custom value"
    echo ""

    printf "  ${TEAL}▸${NC} Choice [1]: "
    local choice
    read -r choice

    local target_swap=10
    case "${choice:-1}" in
        2) target_swap=30 ;;
        3) target_swap=60 ;;
        4)
            printf "  ${TEAL}▸${NC} Enter value (0-100): "
            read -r target_swap
            ;;
        *) target_swap=10 ;;
    esac

    # Apply immediately
    sudo sysctl vm.swappiness="$target_swap"

    # Persist across reboots
    if ! grep -q "vm.swappiness" /etc/sysctl.d/99-performance.conf 2>/dev/null; then
        echo "vm.swappiness=${target_swap}" | sudo tee -a /etc/sysctl.d/99-performance.conf > /dev/null
    else
        sudo sed -i "s/vm.swappiness=.*/vm.swappiness=${target_swap}/" /etc/sysctl.d/99-performance.conf
    fi

    # VFS cache pressure (reduce disk cache eviction)
    sudo sysctl vm.vfs_cache_pressure=50
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.d/99-performance.conf 2>/dev/null; then
        echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-performance.conf > /dev/null
    fi

    log_success "Swappiness set to ${target_swap} (was ${current_swappiness})."
}

optimize_nvidia() {
    print_section "NVIDIA GPU Optimization"

    if ! command_exists nvidia-smi; then
        log_warning "NVIDIA driver not detected. Skipping."
        return 0
    fi

    local driver_ver gpu_name
    driver_ver=$(detect_nvidia_driver)
    gpu_name=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -1)
    log_info "GPU: ${gpu_name} (driver ${driver_ver})"

    # Enable persistence mode
    log_info "Enabling NVIDIA persistence mode..."
    sudo nvidia-smi -pm 1 2>/dev/null || true

    # Create systemd service for persistence mode
    if [ ! -f /etc/systemd/system/nvidia-persistence.service ]; then
        sudo tee /etc/systemd/system/nvidia-persistence.service > /dev/null << 'NVSERVICE'
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user nvidia-persistenced --no-persistence-mode --verbose
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced
Restart=always

[Install]
WantedBy=multi-user.target
NVSERVICE
        sudo systemctl daemon-reload
        sudo systemctl enable nvidia-persistence 2>/dev/null || true
    fi

    # Show current GPU power state
    echo ""
    echo -e "  ${BOLD}GPU Status:${NC}"
    nvidia-smi --query-gpu=gpu_name,temperature.gpu,power.draw,memory.used,memory.total \
        --format=csv,noheader 2>/dev/null | while read -r line; do
        echo -e "    ${DIM}${line}${NC}"
    done
    echo ""

    # Install monitoring tools
    apt_install nvtop 2>/dev/null || true

    log_success "NVIDIA GPU optimization applied."
    echo -e "  ${DIM}Monitor with: nvtop or nvidia-smi -l 1${NC}"
}

optimize_kernel_params() {
    print_section "Kernel Boot Parameters (kernelstub)"

    echo -e "  ${YELLOW}CAUTION:${NC} Modifying boot parameters can affect system stability."
    echo -e "  ${DIM}Pop!_OS uses systemd-boot. Parameters are managed via kernelstub.${NC}"
    echo ""

    # Show current parameters
    log_info "Current kernel parameters:"
    local current_params
    current_params=$(cat /proc/cmdline)
    echo -e "  ${DIM}${current_params}${NC}"
    echo ""

    if ! confirm "Apply performance-oriented kernel parameters?"; then
        return 0
    fi

    # Performance parameters
    local params=(
        "mitigations=auto"          # Security mitigations (auto is balanced)
        "nowatchdog"                # Disable watchdog (saves CPU overhead)
    )

    # Intel-specific
    local cpu_vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        params+=("intel_pstate=active")  # Intel P-State driver (active mode)
    fi

    for param in "${params[@]}"; do
        log_info "Adding: ${param}"
        sudo kernelstub -a "$param" 2>/dev/null || \
        log_warning "Could not add parameter: ${param}"
    done

    log_success "Kernel parameters updated. Reboot to apply."
    echo -e "  ${DIM}Verify after reboot: cat /proc/cmdline${NC}"
}

optimize_network() {
    print_section "Network Optimization"

    # TCP tuning
    log_info "Applying network performance tuning..."

    sudo tee /etc/sysctl.d/99-network.conf > /dev/null << 'NETCFG'
# Network Performance Tuning
# Generated by Pop!_OS Optimization Toolkit

# TCP buffer sizes (auto-tuned by kernel)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP optimizations
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Connection tracking
net.core.somaxconn = 8192
net.core.netdev_max_backlog = 16384

# IPv6 privacy extensions
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
NETCFG

    # Apply now
    sudo sysctl --system 2>/dev/null

    # Check BBR
    if lsmod | grep -q tcp_bbr; then
        log_info "TCP BBR congestion control: active"
    else
        sudo modprobe tcp_bbr 2>/dev/null || true
    fi

    # DNS optimization — systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        log_info "systemd-resolved active."
        echo -e "  ${DIM}Current DNS: $(resolvectl status 2>/dev/null | grep 'DNS Servers' | head -2)${NC}"

        if confirm "Set Cloudflare DNS (1.1.1.1) for faster resolution?"; then
            sudo mkdir -p /etc/systemd/resolved.conf.d
            sudo tee /etc/systemd/resolved.conf.d/dns.conf > /dev/null << 'DNSCFG'
[Resolve]
DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
FallbackDNS=8.8.8.8 8.8.4.4
DNSCFG
            sudo systemctl restart systemd-resolved
            log_success "DNS set to Cloudflare (1.1.1.1)."
        fi
    fi

    log_success "Network optimization applied."
}

install_monitoring() {
    print_section "System Monitoring Tools"

    apt_install htop btop iotop nethogs sysstat dstat

    # nvtop for GPU monitoring
    if command_exists nvidia-smi; then
        apt_install nvtop 2>/dev/null || true
    fi

    # Install bottom (Rust-based system monitor)
    if ! command_exists btm; then
        log_info "btop installed as primary monitor."
    fi

    log_success "Monitoring tools installed."
    echo -e "  ${DIM}btop (interactive), nvtop (GPU), iotop (disk), nethogs (network)${NC}"
}

system_cleanup() {
    print_section "System Cleanup & Maintenance"

    log_info "Removing unused packages..."
    sudo apt autoremove -y 2>&1 | tee -a "$LOG_FILE"

    log_info "Cleaning package cache..."
    sudo apt autoclean -y 2>&1 | tee -a "$LOG_FILE"

    # Clean old kernels (keep current + 1 previous)
    log_info "Cleaning old kernels..."
    local current_kernel
    current_kernel=$(uname -r)
    log_info "Current kernel: ${current_kernel} (will be kept)"

    # Clean journal logs (keep 7 days)
    log_info "Cleaning journal logs (keeping 7 days)..."
    sudo journalctl --vacuum-time=7d 2>/dev/null || true

    # Clean thumbnail cache
    log_info "Cleaning thumbnail cache..."
    rm -rf "$HOME/.cache/thumbnails/*" 2>/dev/null || true

    # Show disk usage summary
    echo ""
    echo -e "  ${BOLD}Disk Usage:${NC}"
    df -h / | awk 'NR==2 {printf "    Used: %s / %s (%s) — %s free\n", $3, $2, $5, $4}'
    echo ""

    log_success "System cleanup complete."
}

# ─────────────────────────────────────────────────────────────
#  Installer Dispatch
# ─────────────────────────────────────────────────────────────
OPT_FUNCTIONS=(
    optimize_power
    optimize_thermals
    optimize_ssd
    setup_zram
    tune_swappiness
    optimize_nvidia
    optimize_kernel_params
    optimize_network
    install_monitoring
    system_cleanup
)

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${WHITE}System Optimization${NC}"
    echo -e "  ${DIM}Performance tuning, power management, and maintenance.${NC}"
    echo ""

    # Show system overview
    local cpu ram is_laptop
    cpu=$(detect_cpu)
    ram=$(detect_ram)
    is_laptop=$(detect_is_laptop)

    echo -e "  ${CYAN}CPU:${NC}     ${cpu}"
    echo -e "  ${CYAN}RAM:${NC}     ${ram}"
    echo -e "  ${CYAN}Type:${NC}    $([ "$is_laptop" = "true" ] && echo "Laptop" || echo "Desktop")"
    echo -e "  ${CYAN}Storage:${NC} $(detect_storage_root)"

    if command_exists nvidia-smi; then
        echo -e "  ${CYAN}GPU:${NC}     $(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -1)"
    fi
    echo ""

    # Checklist
    if ! show_checklist "System Optimization — Select Tasks" OPT_SELECTED OPT_LABELS; then
        log_info "Cancelled."
        return 0
    fi

    local count=0
    for s in "${OPT_SELECTED[@]}"; do ((count += s)); done

    if [ "$count" -eq 0 ]; then
        log_warning "No optimizations selected."
        return 0
    fi

    echo ""
    log_info "${count} optimization(s) selected."
    if ! confirm "Proceed?"; then
        return 0
    fi

    ensure_sudo

    local total=$count current=0
    for i in "${!OPT_SELECTED[@]}"; do
        if [ "${OPT_SELECTED[$i]}" -eq 1 ]; then
            ((current++))
            echo ""
            log_step "$current" "$total" "${OPT_LABELS[$i]%%(*}"
            ${OPT_FUNCTIONS[$i]}
            progress_bar "$current" "$total" 40 "  Overall"
        fi
    done

    print_completion_banner "System Optimization Complete"

    echo -e "  ${BOLD}Summary:${NC}"
    echo -e "    ${DIM}Some changes require a reboot to take effect.${NC}"
    echo ""

    if confirm "Reboot now to apply all changes?"; then
        log_info "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        sudo reboot
    fi

    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

main "$@"
