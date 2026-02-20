#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — Master Installer                            ║
# ║                                                                              ║
# ║  Interactive entry point that detects hardware, identifies your machine,     ║
# ║  and guides you through selecting which modules to install.                  ║
# ║                                                                              ║
# ║  Usage:  ./install.sh [--dry-run] [--help]                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Resolve script directory ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ─────────────────────────────────────────────────────────────
#  CLI Arguments
# ─────────────────────────────────────────────────────────────
show_help() {
    cat << 'EOF'

  Pop!_OS Optimization Toolkit

  USAGE:
      ./install.sh [OPTIONS]

  OPTIONS:
      --help, -h        Show this help message
      --dry-run         Preview what would be installed (no changes)
      --dev             Run only the Developer Tools setup
      --ai              Run only the AI/ML Workstation setup
      --gaming          Run only the Gaming Optimization setup
      --robotics        Run only the Robotics Lab setup
      --ssh             Run only the SSH Configuration
      --optimize        Run only the System Optimization
      --all             Install everything (non-interactive)

  EXAMPLES:
      ./install.sh              Interactive mode (recommended)
      ./install.sh --dry-run    Preview without installing
      ./install.sh --dev --ai   Install dev tools and AI stack

EOF
    exit 0
}

# Parse arguments
MODULES=()
for arg in "$@"; do
    case "$arg" in
        --help|-h)   show_help ;;
        --dry-run)   export DRY_RUN=true ;;
        --dev)       MODULES+=("dev") ;;
        --ai)        MODULES+=("ai") ;;
        --gaming)    MODULES+=("gaming") ;;
        --robotics)  MODULES+=("robotics") ;;
        --ssh)       MODULES+=("ssh") ;;
        --optimize)  MODULES+=("optimize") ;;
        --all)       MODULES=("dev" "ai" "gaming" "robotics" "ssh" "optimize") ;;
        *)
            echo "Unknown option: $arg"
            echo "Run './install.sh --help' for usage."
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────
#  System Greeting (Hardware-Aware)
# ─────────────────────────────────────────────────────────────
show_greeting() {
    local model manufacturer cpu is_laptop gpu_tier

    model=$(detect_laptop_model)
    manufacturer=$(detect_manufacturer)
    cpu=$(detect_cpu)
    is_laptop=$(detect_is_laptop)
    gpu_tier=$(detect_gpu_tier)

    local greeting=""
    local tip=""

    # Machine-specific greetings
    case "$manufacturer" in
        *Lenovo*)
            greeting="Lenovo ThinkPad detected — workstation-grade Linux machine. Welcome home."
            ;;
        *Dell*)
            greeting="Dell system detected — great Linux hardware support."
            ;;
        *HP*|*Hewlett*)
            greeting="HP system detected — solid workstation platform."
            ;;
        *System76*)
            greeting="System76 machine detected — Pop!_OS native hardware!"
            ;;
        *ASUS*)
            greeting="ASUS system detected — let's optimze your setup."
            ;;
        *Acer*)
            greeting="Acer system detected — ready to configure."
            ;;
        *MSI*)
            greeting="MSI system detected — performance hardware ready."
            ;;
        *)
            greeting="System detected — let's configure your workstation."
            ;;
    esac

    # GPU-aware tips
    case "$gpu_tier" in
        ultra)
            tip="Your GPU is exceptional — you can run the largest AI models locally."
            ;;
        high)
            tip="Powerful GPU detected — ideal for AI, gaming, and CAD workloads."
            ;;
        medium)
            tip="Good GPU detected — runs most AI models and games well."
            ;;
        entry)
            tip="Entry-level GPU detected — optimized model recommendations provided."
            ;;
        minimal)
            tip="Minimal GPU — CPU-based workloads recommended for AI tasks."
            ;;
        *)
            tip="GPU detection skipped — recommendations will use defaults."
            ;;
    esac

    # Laptop vs Desktop tips
    if [ "$is_laptop" = "true" ]; then
        tip="${tip}\n  Power management profiles available for battery optimization."
    fi

    echo ""
    echo -e "  ${TEAL}▸${NC}  ${BOLD}${greeting}${NC}"
    echo -e "  ${LIGHT_BLUE}▸${NC}  ${tip}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
#  Module Launchers
# ─────────────────────────────────────────────────────────────
run_module() {
    local module="$1"
    local script=""

    case "$module" in
        dev)       script="${SCRIPT_DIR}/scripts/dev-setup.sh" ;;
        ai)        script="${SCRIPT_DIR}/scripts/ai-setup.sh" ;;
        gaming)    script="${SCRIPT_DIR}/scripts/gaming-setup.sh" ;;
        robotics)  script="${SCRIPT_DIR}/scripts/robotics-setup.sh" ;;
        ssh)       script="${SCRIPT_DIR}/scripts/ssh-setup.sh" ;;
        optimize)  script="${SCRIPT_DIR}/scripts/system-optimize.sh" ;;
        *)
            log_error "Unknown module: $module"
            return 1
            ;;
    esac

    if [ ! -f "$script" ]; then
        log_error "Script not found: $script"
        return 1
    fi

    bash "$script"
}

# ─────────────────────────────────────────────────────────────
#  Non-Interactive Mode (CLI flags)
# ─────────────────────────────────────────────────────────────
if [ ${#MODULES[@]} -gt 0 ]; then
    clear_screen
    print_system_banner
    show_greeting

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}★  DRY RUN MODE — No changes will be made${NC}"
        echo ""
    fi

    ensure_sudo
    check_internet || exit 1

    for module in "${MODULES[@]}"; do
        run_module "$module"
    done

    print_completion_banner "All Selected Modules Installed"
    exit 0
fi

# ─────────────────────────────────────────────────────────────
#  Interactive Mode — Main Menu Loop
# ─────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        clear_screen
        print_system_banner
        show_greeting

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "  ${YELLOW}★  DRY RUN MODE — No changes will be made${NC}"
            echo ""
        fi

        local width=58

        draw_box_top $width "$TEAL"
        draw_box_line_centered "MAIN MENU" $width "$TEAL" "${BOLD}${ORANGE}"
        draw_box_middle $width "$TEAL"
        draw_empty_line $width "$TEAL"
        draw_box_line "  ${TEAL}[${WHITE}1${TEAL}]${NC}  Developer Tools Setup" $width "$TEAL" "$NC"
        draw_box_line "       ${DIM}Git, Python, Node.js, Docker, editors${NC}" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_line "  ${TEAL}[${WHITE}2${TEAL}]${NC}  AI / ML Workstation Setup" $width "$TEAL" "$NC"
        draw_box_line "       ${DIM}Ollama, LLMs, CUDA, Jupyter, Open WebUI${NC}" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_line "  ${TEAL}[${WHITE}3${TEAL}]${NC}  Gaming Optimization" $width "$TEAL" "$NC"
        draw_box_line "       ${DIM}Steam, Proton, GameMode, GPU passthrough${NC}" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_line "  ${TEAL}[${WHITE}4${TEAL}]${NC}  Robotics Lab (ROS 2)" $width "$TEAL" "$NC"
        draw_box_line "       ${DIM}ROS 2, SLAM, Gazebo, Arduino bridge${NC}" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_line "  ${TEAL}[${WHITE}5${TEAL}]${NC}  SSH Configuration" $width "$TEAL" "$NC"
        draw_box_line "       ${DIM}Key generation, agent, GitHub/GitLab setup${NC}" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_line "  ${TEAL}[${WHITE}6${TEAL}]${NC}  System Optimization" $width "$TEAL" "$NC"
        draw_box_line "       ${DIM}Power, thermals, SSD, swap, performance${NC}" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_middle $width "$TEAL"
        draw_box_line "  ${GREEN}[${WHITE}7${GREEN}]${NC}  Install Everything" $width "$TEAL" "$NC"
        draw_box_line "  ${RED}[${WHITE}0${RED}]${NC}  Exit" $width "$TEAL" "$NC"
        draw_empty_line $width "$TEAL"
        draw_box_bottom $width "$TEAL"

        echo ""
        local choice
        printf "  ${TEAL}▸${NC} Select an option: "
        read -r choice

        case "$choice" in
            1) run_module "dev" ;;
            2) run_module "ai" ;;
            3) run_module "gaming" ;;
            4) run_module "robotics" ;;
            5) run_module "ssh" ;;
            6) run_module "optimize" ;;
            7)
                ensure_sudo
                check_internet || continue
                for mod in dev ai gaming robotics ssh optimize; do
                    run_module "$mod"
                done
                print_completion_banner "Full Installation Complete"
                echo -e "  ${DIM}Press Enter to return to menu...${NC}"
                read -r
                ;;
            0|q|Q)
                clear_screen
                echo ""
                echo -e "  ${TEAL}Thanks for using the Pop!_OS Optimization Toolkit.${NC}"
                echo -e "  ${DIM}Log saved to: ${LOG_FILE}${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "  ${RED}Invalid option. Press Enter to continue...${NC}"
                read -r
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────
#  Entry Point
# ─────────────────────────────────────────────────────────────
main_menu
