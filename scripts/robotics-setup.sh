#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — Robotics Lab Setup (ROS 2)                  ║
# ║                                                                              ║
# ║  Installs ROS 2 Humble, SLAM, Gazebo simulation, Arduino bridge,            ║
# ║  and computer vision tools for robotics development.                         ║
# ║                                                                              ║
# ║  Target: Pop!_OS 22.04 (Ubuntu 22.04 Jammy base) → ROS 2 Humble Hawksbill  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ─────────────────────────────────────────────────────────────
#  Package Groups
# ─────────────────────────────────────────────────────────────
ROBOTICS_LABELS=(
    "ROS 2 Humble Desktop   (Full desktop install + dev tools)"
    "Navigation 2 Stack     (Nav2, SLAM Toolbox, AMCL)"
    "Gazebo Simulation      (Gazebo + ROS 2 integration)"
    "TurtleBot3 Packages    (Simulation & real robot support)"
    "MoveIt 2               (Motion planning framework)"
    "Arduino / Embedded     (Arduino CLI, PlatformIO, pyserial)"
    "Computer Vision (ROS)  (cv_bridge, image_transport, OpenCV)"
    "ROS 2 Dev Tools        (colcon, rosdep, vcstool, bloom)"
    "Micro-ROS              (ROS 2 for microcontrollers)"
    "RViz Plugins           (Extra visualization plugins)"
)

ROBOTICS_SELECTED=(1 1 1 1 0 1 1 1 0 1)

# ─────────────────────────────────────────────────────────────
#  ROS 2 Repository Setup
# ─────────────────────────────────────────────────────────────
setup_ros2_repo() {
    print_section "Setting Up ROS 2 Repository"

    # Check Ubuntu codename
    local codename="unknown"
    if [ -f /etc/os-release ]; then
        codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-jammy}")
    fi

    if [[ "$codename" != "jammy" ]]; then
        log_warning "ROS 2 Humble targets Ubuntu 22.04 (Jammy). Detected: ${codename}"
        log_warning "Installation may not work correctly on this base."
        if ! confirm "Continue anyway?"; then
            return 1
        fi
    fi

    # Install prerequisites
    apt_install software-properties-common curl gnupg lsb-release

    # Add ROS 2 GPG key
    if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then
        log_info "Adding ROS 2 repository key..."
        sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
            -o /usr/share/keyrings/ros-archive-keyring.gpg
    fi

    # Add repository
    if [ ! -f /etc/apt/sources.list.d/ros2.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu ${codename} main" \
            | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
    fi

    # Add universe repository
    sudo add-apt-repository -y universe 2>/dev/null || true
    sudo apt update

    log_success "ROS 2 repository configured."
}

# ─────────────────────────────────────────────────────────────
#  Installation Functions
# ─────────────────────────────────────────────────────────────

install_ros2_desktop() {
    print_section "ROS 2 Humble — Desktop Install"

    setup_ros2_repo

    log_info "Installing ROS 2 Humble Desktop (this may take several minutes)..."
    apt_install ros-humble-desktop ros-humble-ros-base ros-dev-tools

    # Source ROS 2 in shell
    local shell_rc="$HOME/.bashrc"
    local source_line="source /opt/ros/humble/setup.bash"

    if ! grep -q "$source_line" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# ROS 2 Humble Hawksbill" >> "$shell_rc"
        echo "$source_line" >> "$shell_rc"
        log_info "Added ROS 2 sourcing to ${shell_rc}"
    fi

    # Initialize rosdep
    if [ ! -d /etc/ros/rosdep ]; then
        sudo rosdep init 2>/dev/null || log_info "rosdep already initialized."
    fi
    rosdep update 2>/dev/null || true

    log_success "ROS 2 Humble Desktop installed."
    echo -e "  ${DIM}Source with: source /opt/ros/humble/setup.bash${NC}"
    echo -e "  ${DIM}Test with:   ros2 run demo_nodes_cpp talker${NC}"
}

install_nav2() {
    print_section "Navigation 2 Stack"

    apt_install \
        ros-humble-navigation2 \
        ros-humble-nav2-bringup \
        ros-humble-slam-toolbox \
        ros-humble-robot-localization \
        ros-humble-cartographer \
        ros-humble-cartographer-ros

    log_success "Navigation 2 & SLAM packages installed."
    echo -e "  ${DIM}Includes: Nav2, SLAM Toolbox, Cartographer, robot_localization${NC}"
}

install_gazebo() {
    print_section "Gazebo Simulation"

    apt_install \
        ros-humble-gazebo-ros \
        ros-humble-gazebo-ros-pkgs \
        ros-humble-gazebo-plugins \
        ros-humble-gazebo-ros2-control

    log_success "Gazebo + ROS 2 integration installed."
    echo -e "  ${DIM}Launch: gazebo --verbose (or via ROS 2 launch files)${NC}"
}

install_turtlebot3() {
    print_section "TurtleBot3 Packages"

    apt_install \
        ros-humble-turtlebot3 \
        ros-humble-turtlebot3-simulations \
        ros-humble-turtlebot3-navigation2 \
        ros-humble-turtlebot3-cartographer \
        ros-humble-turtlebot3-teleop

    # Set default model
    local shell_rc="$HOME/.bashrc"
    if ! grep -q "TURTLEBOT3_MODEL" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# TurtleBot3 default model" >> "$shell_rc"
        echo 'export TURTLEBOT3_MODEL=burger' >> "$shell_rc"
    fi

    log_success "TurtleBot3 packages installed."
    echo ""
    echo -e "  ${BOLD}Quick SLAM Demo:${NC}"
    echo -e "  ${DIM}  Terminal 1: ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py${NC}"
    echo -e "  ${DIM}  Terminal 2: ros2 launch turtlebot3_cartographer cartographer.launch.py use_sim_time:=True${NC}"
    echo -e "  ${DIM}  Terminal 3: ros2 run turtlebot3_teleop teleop_keyboard${NC}"
}

install_moveit2() {
    print_section "MoveIt 2 — Motion Planning"

    apt_install \
        ros-humble-moveit \
        ros-humble-moveit-configs-utils \
        ros-humble-moveit-ros-visualization

    log_success "MoveIt 2 installed."
    echo -e "  ${DIM}Tutorial: https://moveit.picknik.ai/humble/index.html${NC}"
}

install_arduino() {
    print_section "Arduino & Embedded Tools"

    # Arduino CLI
    if ! command_exists arduino-cli; then
        log_info "Installing Arduino CLI..."
        curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh -s -- --dest "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
    else
        log_info "Arduino CLI already installed."
    fi

    # PlatformIO
    if ! command_exists platformio 2>/dev/null; then
        log_info "Installing PlatformIO..."
        pip_install platformio
    fi

    # Python serial for ROS ↔ Arduino bridge
    pip_install pyserial

    # Add user to dialout group for serial port access
    if ! groups "$USER" | grep -q dialout; then
        sudo usermod -aG dialout "$USER"
        log_warning "Added to 'dialout' group. Log out and back in for serial port access."
    fi

    # Install ros-humble-micro-ros-agent for serial comms
    apt_install ros-humble-rosserial-msgs 2>/dev/null || \
    log_info "rosserial not available; use micro-ros or custom serial bridge."

    log_success "Arduino & embedded tools installed."
    echo -e "  ${DIM}Arduino CLI: arduino-cli board list${NC}"
    echo -e "  ${DIM}PlatformIO:  pio boards${NC}"
}

install_cv_ros() {
    print_section "Computer Vision (ROS 2)"

    apt_install \
        ros-humble-cv-bridge \
        ros-humble-image-transport \
        ros-humble-image-transport-plugins \
        ros-humble-vision-opencv \
        ros-humble-image-pipeline \
        ros-humble-depth-image-proc

    # Python CV libraries
    pip_install opencv-python ultralytics

    log_success "Computer vision ROS packages installed."
}

install_ros2_dev_tools() {
    print_section "ROS 2 Development Tools"

    apt_install \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        python3-bloom \
        python3-rosinstall-generator

    # colcon autocomplete
    local shell_rc="$HOME/.bashrc"
    local colcon_line="source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"
    if ! grep -q "colcon-argcomplete" "$shell_rc" 2>/dev/null; then
        echo "$colcon_line" >> "$shell_rc" 2>/dev/null || true
    fi

    log_success "ROS 2 development tools installed."
    echo -e "  ${DIM}Build workspace: cd ~/ros2_ws && colcon build --symlink-install${NC}"
}

install_micro_ros() {
    print_section "Micro-ROS — ROS 2 for Microcontrollers"

    # Install micro-ROS agent
    apt_install ros-humble-micro-ros-agent 2>/dev/null || {
        log_info "Installing micro-ROS from source..."
        local ws="$HOME/microros_ws"
        mkdir -p "$ws/src"
        cd "$ws"
        git clone -b humble https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup 2>/dev/null || true
        source /opt/ros/humble/setup.bash
        rosdep update
        rosdep install --from-paths src --ignore-src -y 2>/dev/null || true
        colcon build
    }

    log_success "Micro-ROS installed."
    echo -e "  ${DIM}Supports: ESP32, STM32, Arduino, Teensy, Raspberry Pi Pico${NC}"
}

install_rviz_plugins() {
    print_section "RViz Plugins & Visualization"

    apt_install \
        ros-humble-rviz2 \
        ros-humble-rviz-common \
        ros-humble-rviz-default-plugins \
        ros-humble-rviz-visual-tools \
        ros-humble-rqt \
        ros-humble-rqt-common-plugins \
        ros-humble-rqt-graph \
        ros-humble-rqt-tf-tree \
        ros-humble-rqt-topic \
        ros-humble-plotjuggler-ros

    log_success "RViz plugins and visualization tools installed."
    echo -e "  ${DIM}Launch RViz: rviz2${NC}"
    echo -e "  ${DIM}Launch rqt:  rqt${NC}"
}

# ─────────────────────────────────────────────────────────────
#  Workspace Setup
# ─────────────────────────────────────────────────────────────
setup_ros2_workspace() {
    print_section "ROS 2 Workspace"

    local ws="$HOME/ros2_ws"
    if [ -d "$ws" ]; then
        log_info "Workspace already exists at ${ws}"
        return 0
    fi

    mkdir -p "$ws/src"
    cd "$ws"

    source /opt/ros/humble/setup.bash 2>/dev/null || true
    colcon build --symlink-install 2>/dev/null || true

    # Add workspace sourcing
    local shell_rc="$HOME/.bashrc"
    local ws_source="source ${ws}/install/setup.bash"
    if ! grep -q "$ws_source" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# ROS 2 workspace" >> "$shell_rc"
        echo "$ws_source" >> "$shell_rc"
    fi

    log_success "ROS 2 workspace created at ${ws}"
}

# ─────────────────────────────────────────────────────────────
#  Installer Dispatch
# ─────────────────────────────────────────────────────────────
ROBOTICS_FUNCTIONS=(
    install_ros2_desktop
    install_nav2
    install_gazebo
    install_turtlebot3
    install_moveit2
    install_arduino
    install_cv_ros
    install_ros2_dev_tools
    install_micro_ros
    install_rviz_plugins
)

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${WHITE}Robotics Lab Setup (ROS 2 Humble)${NC}"
    echo -e "  ${DIM}Full robotics development environment with SLAM, simulation & embedded.${NC}"
    echo ""

    # Check ROS 2 compatibility
    local codename="unknown"
    if [ -f /etc/os-release ]; then
        codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-unknown}")
    fi
    echo -e "  ${CYAN}Ubuntu base:${NC} ${codename}"
    echo -e "  ${CYAN}ROS 2:${NC}       Humble Hawksbill (LTS)"

    if [[ "$codename" != "jammy" ]]; then
        echo ""
        log_warning "ROS 2 Humble is designed for Ubuntu 22.04 (Jammy)."
        log_warning "Your system base is: ${codename}"
    fi
    echo ""

    # Scan existing
    log_info "Scanning existing installations..."
    [ -d /opt/ros/humble ]            && log_info "ROS 2 Humble: installed" || true
    command_exists gazebo              && log_info "Gazebo: installed" || true
    command_exists arduino-cli         && log_info "Arduino CLI: installed" || true
    [ -d "$HOME/ros2_ws" ]            && log_info "ROS 2 workspace: exists" || true
    echo ""

    # Checklist
    if ! show_checklist "Robotics Lab — Select Components" ROBOTICS_SELECTED ROBOTICS_LABELS; then
        log_info "Cancelled."
        return 0
    fi

    local count=0
    for s in "${ROBOTICS_SELECTED[@]}"; do ((count += s)); done

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
    for i in "${!ROBOTICS_SELECTED[@]}"; do
        if [ "${ROBOTICS_SELECTED[$i]}" -eq 1 ]; then
            ((current++))
            echo ""
            log_step "$current" "$total" "${ROBOTICS_LABELS[$i]%%(*}"
            ${ROBOTICS_FUNCTIONS[$i]}
            progress_bar "$current" "$total" 40 "  Overall"
        fi
    done

    # Create workspace
    echo ""
    if confirm "Create a ROS 2 workspace at ~/ros2_ws?"; then
        setup_ros2_workspace
    fi

    print_completion_banner "Robotics Lab Setup Complete"

    echo -e "  ${BOLD}Quick Start:${NC}"
    echo -e "    ${TEAL}1.${NC} Source ROS 2:  ${DIM}source /opt/ros/humble/setup.bash${NC}"
    echo -e "    ${TEAL}2.${NC} Run demo:      ${DIM}ros2 run demo_nodes_cpp talker${NC}"
    echo -e "    ${TEAL}3.${NC} SLAM sim:      ${DIM}ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py${NC}"
    echo -e "    ${TEAL}4.${NC} Build ws:      ${DIM}cd ~/ros2_ws && colcon build${NC}"
    echo ""

    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

main "$@"
