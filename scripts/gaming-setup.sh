#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — Gaming Optimization Setup                   ║
# ║                                                                              ║
# ║  Configures native Linux gaming, Steam/Proton, performance tools,            ║
# ║  and optional GPU passthrough for Windows VMs.                               ║
# ║                                                                              ║
# ║  NOTE: Pop!_OS uses systemd-boot (not GRUB). Boot parameters are managed    ║
# ║  via kernelstub, not /etc/default/grub.                                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ─────────────────────────────────────────────────────────────
#  Package Groups
# ─────────────────────────────────────────────────────────────
GAMING_LABELS=(
    "Steam                  (Steam client via apt)"
    "Heroic Launcher        (Epic Games / GOG on Linux)"
    "Lutris                 (Universal gaming platform)"
    "GameMode               (CPU/GPU game-time optimization)"
    "MangoHud               (FPS overlay & performance monitor)"
    "Vulkan & Mesa Drivers  (Vulkan runtime, tools, Mesa)"
    "ProtonUp-Qt            (Manage custom Proton versions)"
    "Wine & Dependencies    (Wine staging + essentials)"
    "GPU Passthrough (KVM)  (Windows VM with near-native GPU)"
    "Controller Support     (Xbox, PS4/PS5, Steam controllers)"
)

GAMING_SELECTED=(1 0 1 1 1 1 1 0 0 1)

# ─────────────────────────────────────────────────────────────
#  Installation Functions
# ─────────────────────────────────────────────────────────────

install_steam() {
    print_section "Steam"

    if is_installed steam-installer 2>/dev/null || command_exists steam; then
        log_info "Steam is already installed."
    else
        log_info "Installing Steam..."
        # Enable i386 architecture for Steam
        sudo dpkg --add-architecture i386
        sudo apt update
        apt_install steam-installer
    fi

    log_success "Steam installed."
    echo -e "  ${DIM}Enable Proton: Steam > Settings > Compatibility > Enable Steam Play${NC}"
    echo -e "  ${DIM}Recommended: Proton Experimental or GE-Proton (via ProtonUp-Qt)${NC}"
}

install_heroic() {
    print_section "Heroic Games Launcher"

    if command_exists flatpak; then
        log_info "Installing Heroic via Flatpak..."
        flatpak_install com.heroicgameslauncher.hgl
    else
        log_info "Installing Heroic via .deb..."
        local latest_url
        latest_url=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
            | grep "browser_download_url.*amd64.deb" | head -1 | cut -d'"' -f4)
        if [ -n "$latest_url" ]; then
            wget -O /tmp/heroic.deb "$latest_url"
            sudo dpkg -i /tmp/heroic.deb || sudo apt install -f -y
            rm -f /tmp/heroic.deb
        else
            log_warning "Could not find Heroic .deb. Install via Flatpak or Pop!_Shop."
        fi
    fi

    log_success "Heroic Games Launcher installed."
}

install_lutris() {
    print_section "Lutris"

    if command_exists lutris; then
        log_info "Lutris already installed."
    else
        log_info "Installing Lutris..."
        sudo add-apt-repository -y ppa:lutris-team/lutris 2>/dev/null || true
        sudo apt update
        apt_install lutris
    fi

    log_success "Lutris installed."
}

install_gamemode() {
    print_section "GameMode"

    apt_install gamemode

    # Enable GameMode for current user
    log_info "GameMode allows games to request a set of optimisations temporarily."
    echo -e "  ${DIM}Usage: gamemoderun ./your-game${NC}"
    echo -e "  ${DIM}Steam: Set launch options to 'gamemoderun %command%'${NC}"
    echo ""

    # Test GameMode
    if command_exists gamemoded; then
        gamemoded -t 2>/dev/null && log_success "GameMode is working." || \
        log_warning "GameMode test returned non-zero. It may still work in-game."
    fi

    log_success "GameMode installed."
}

install_mangohud() {
    print_section "MangoHud — Performance Overlay"

    apt_install mangohud

    # Create default MangoHud config
    local config_dir="$HOME/.config/MangoHud"
    mkdir -p "$config_dir"

    if [ ! -f "$config_dir/MangoHud.conf" ]; then
        cat > "$config_dir/MangoHud.conf" << 'MANGOCFG'
### MangoHud Configuration
### Reference: https://github.com/flightlessmango/MangoHud

# Position & Layout
position=top-left
round_corners=8
font_size=20
background_alpha=0.4

# Displayed Metrics
fps
frametime
gpu_stats
gpu_temp
gpu_power
gpu_mem_clock
cpu_stats
cpu_temp
cpu_power
ram
vram
frame_timing

# Visual Style
fps_color_change
engine_color=eb5b5b
wine_color=eb5b5b
MANGOCFG
        log_info "Created MangoHud config at ${config_dir}/MangoHud.conf"
    fi

    echo -e "  ${DIM}Usage: mangohud ./your-game${NC}"
    echo -e "  ${DIM}Steam: Set launch options to 'mangohud %command%'${NC}"
    echo -e "  ${DIM}Both: 'gamemoderun mangohud %command%'${NC}"

    log_success "MangoHud installed."
}

install_vulkan() {
    print_section "Vulkan & Mesa Drivers"

    # Enable 32-bit libraries
    sudo dpkg --add-architecture i386
    sudo apt update

    apt_install \
        vulkan-tools \
        mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
        libvulkan1 libvulkan1:i386 \
        vulkan-validationlayers

    # NVIDIA Vulkan ICD (should be present with NVIDIA driver)
    if command_exists nvidia-smi; then
        apt_install libnvidia-gl-535:i386 2>/dev/null || \
        log_info "32-bit NVIDIA GL libraries may already be installed."
    fi

    # Verify Vulkan
    if command_exists vulkaninfo; then
        local vulkan_ver
        vulkan_ver=$(vulkaninfo --summary 2>/dev/null | grep "apiVersion" | head -1 | awk '{print $NF}')
        log_info "Vulkan API: ${vulkan_ver:-detected}"
    fi

    log_success "Vulkan drivers installed."
}

install_protonup() {
    print_section "ProtonUp-Qt — Proton Version Manager"

    if command_exists flatpak; then
        flatpak_install net.davidotek.pupgui2
    else
        pip_install protonup-qt 2>/dev/null || \
        log_warning "Install via Flatpak or from: https://github.com/DavidoTek/ProtonUp-Qt"
    fi

    log_success "ProtonUp-Qt installed."
    echo -e "  ${DIM}Use ProtonUp-Qt to install GE-Proton for better game compatibility.${NC}"
}

install_wine() {
    print_section "Wine & Dependencies"

    sudo dpkg --add-architecture i386
    sudo apt update
    apt_install wine64 wine32 winetricks

    log_success "Wine installed."
}

install_gpu_passthrough() {
    print_section "GPU Passthrough (KVM/QEMU)"

    local width=58
    echo ""
    draw_box_top $width "$YELLOW"
    draw_box_line_centered "ADVANCED: GPU Passthrough Setup" $width "$YELLOW" "${BOLD}${WHITE}"
    draw_box_middle $width "$YELLOW"
    draw_box_line "  This enables running Windows in a VM with" $width "$YELLOW" "$NC"
    draw_box_line "  near-native GPU performance for gaming." $width "$YELLOW" "$NC"
    draw_empty_line $width "$YELLOW"
    draw_box_line "  ${BOLD}Requirements:${NC}" $width "$YELLOW" "$NC"
    draw_box_line "    - Two GPUs (iGPU + dGPU) or a spare GPU" $width "$YELLOW" "$NC"
    draw_box_line "    - CPU virtualization (VT-x/VT-d) in BIOS" $width "$YELLOW" "$NC"
    draw_box_line "    - IOMMU support" $width "$YELLOW" "$NC"
    draw_box_line "    - 16GB+ RAM recommended" $width "$YELLOW" "$NC"
    draw_empty_line $width "$YELLOW"
    draw_box_bottom $width "$YELLOW"
    echo ""

    if ! confirm "Continue with KVM/QEMU setup?"; then
        return 0
    fi

    # Step 1: Install KVM/QEMU
    log_info "Installing KVM, QEMU, and virt-manager..."
    apt_install qemu-kvm libvirt-daemon-system libvirt-clients \
        virt-manager ovmf bridge-utils

    # Enable libvirtd
    sudo systemctl enable --now libvirtd

    # Add user to groups
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG kvm "$USER"

    log_success "KVM/QEMU installed."

    # Step 2: Check IOMMU
    echo ""
    print_section "Checking IOMMU Support"

    local iommu_status
    iommu_status=$(dmesg 2>/dev/null | grep -i -E "DMAR|IOMMU" | head -3)

    if [ -n "$iommu_status" ]; then
        log_success "IOMMU support detected:"
        echo -e "  ${DIM}${iommu_status}${NC}"
    else
        log_warning "IOMMU not detected in dmesg. It may need to be enabled."
    fi

    # Step 3: Enable IOMMU via kernelstub (Pop!_OS specific)
    echo ""
    print_section "IOMMU Boot Parameter"

    # Detect CPU vendor for correct IOMMU parameter
    local cpu_vendor iommu_param
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        iommu_param="intel_iommu=on"
    else
        iommu_param="amd_iommu=on"
    fi

    log_info "Detected CPU vendor: ${cpu_vendor}"
    log_info "Required boot parameter: ${iommu_param}"

    echo ""
    echo -e "  ${YELLOW}IMPORTANT:${NC} Pop!_OS uses ${BOLD}systemd-boot${NC}, not GRUB."
    echo -e "  Boot parameters are managed via ${BOLD}kernelstub${NC}."
    echo ""

    if confirm "Add '${iommu_param} iommu=pt' to boot parameters?"; then
        sudo kernelstub -a "${iommu_param}"
        sudo kernelstub -a "iommu=pt"
        log_success "Boot parameters updated. Reboot to apply."
        echo ""
        echo -e "  ${DIM}Verify after reboot with: dmesg | grep -i iommu${NC}"
    else
        echo -e "  ${DIM}To add manually later:${NC}"
        echo -e "  ${DIM}  sudo kernelstub -a \"${iommu_param}\"${NC}"
        echo -e "  ${DIM}  sudo kernelstub -a \"iommu=pt\"${NC}"
    fi

    echo ""
    log_info "GPU passthrough requires additional per-device configuration."
    echo -e "  ${DIM}Next steps:${NC}"
    echo -e "  ${DIM}  1. Reboot and verify IOMMU groups: find /sys/kernel/iommu_groups/ -type l${NC}"
    echo -e "  ${DIM}  2. Identify GPU PCI IDs: lspci -nn | grep NVIDIA${NC}"
    echo -e "  ${DIM}  3. Configure VFIO stub driver for the passthrough GPU${NC}"
    echo -e "  ${DIM}  4. Create Windows VM in virt-manager with OVMF (UEFI)${NC}"
    echo ""

    log_success "GPU passthrough base setup complete."
}

install_controllers() {
    print_section "Game Controller Support"

    # Xbox controllers (xpad/xone)
    apt_install xboxdrv 2>/dev/null || log_info "xboxdrv not available, kernel xpad driver will be used."

    # Steam controller and general HID support
    apt_install steam-devices 2>/dev/null || true

    # PS4/PS5 DualSense support (via kernel — usually built-in on modern kernels)
    log_info "DualSense (PS5) support is built into kernel 5.12+."
    log_info "Current kernel: $(uname -r)"

    # udev rules for better controller support
    if [ ! -f /etc/udev/rules.d/60-steam-input.rules ]; then
        log_info "Steam's controller udev rules will be applied by Steam."
    fi

    log_success "Controller support configured."
    echo -e "  ${DIM}Test with: jstest-gtk or steam big picture mode${NC}"
}

# ─────────────────────────────────────────────────────────────
#  Installer Dispatch
# ─────────────────────────────────────────────────────────────
GAMING_FUNCTIONS=(
    install_steam
    install_heroic
    install_lutris
    install_gamemode
    install_mangohud
    install_vulkan
    install_protonup
    install_wine
    install_gpu_passthrough
    install_controllers
)

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${WHITE}Gaming Optimization Setup${NC}"
    echo -e "  ${DIM}Configure your machine for the best Linux gaming experience.${NC}"
    echo ""

    # Show GPU info
    local gpu driver_ver
    gpu=$(detect_gpu)
    driver_ver=$(detect_nvidia_driver)
    echo -e "  ${CYAN}GPU:${NC}     ${gpu}"
    echo -e "  ${CYAN}Driver:${NC}  ${driver_ver}"
    echo ""

    # Scan existing
    log_info "Scanning existing installations..."
    command_exists steam     && log_info "Steam: installed" || true
    command_exists lutris    && log_info "Lutris: installed" || true
    command_exists gamemoded && log_info "GameMode: installed" || true
    command_exists mangohud  && log_info "MangoHud: installed" || true
    echo ""

    # Checklist
    if ! show_checklist "Gaming — Select Components" GAMING_SELECTED GAMING_LABELS; then
        log_info "Cancelled."
        return 0
    fi

    local count=0
    for s in "${GAMING_SELECTED[@]}"; do ((count += s)); done

    if [ "$count" -eq 0 ]; then
        log_warning "No components selected."
        return 0
    fi

    echo ""
    log_info "${count} component(s) selected."
    if ! confirm "Proceed with installation?"; then
        return 0
    fi

    ensure_sudo
    check_internet || return 1

    print_section "Updating Package Lists" "↻"
    sudo apt update 2>&1 | tee -a "$LOG_FILE"

    local total=$count current=0
    for i in "${!GAMING_SELECTED[@]}"; do
        if [ "${GAMING_SELECTED[$i]}" -eq 1 ]; then
            ((current++))
            echo ""
            log_step "$current" "$total" "${GAMING_LABELS[$i]%%(*}"
            ${GAMING_FUNCTIONS[$i]}
            progress_bar "$current" "$total" 40 "  Overall"
        fi
    done

    print_completion_banner "Gaming Setup Complete"

    echo -e "  ${BOLD}Quick Start:${NC}"
    echo -e "    ${TEAL}1.${NC} Launch Steam and enable Proton"
    echo -e "    ${TEAL}2.${NC} Use ProtonUp-Qt to install GE-Proton"
    echo -e "    ${TEAL}3.${NC} Launch options: ${DIM}gamemoderun mangohud %command%${NC}"
    echo ""

    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

main "$@"
