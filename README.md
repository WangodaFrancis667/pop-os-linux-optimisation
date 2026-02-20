<div align="center">

# Pop!\_OS Optimization Toolkit

**Hardware-aware Linux configuration for Lenovo workstation laptops**

[![Pop!_OS](https://img.shields.io/badge/Pop!__OS-22.04_LTS-48B9C7?style=for-the-badge&logo=pop!_os&logoColor=white)](https://pop.system76.com/)
[![Lenovo](https://img.shields.io/badge/Lenovo-ThinkPad_P_Series-E2231A?style=for-the-badge&logo=lenovo&logoColor=white)](https://www.lenovo.com/)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-RTX_A1000-76B900?style=for-the-badge&logo=nvidia&logoColor=white)](https://www.nvidia.com/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash_5.x-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

An interactive toolkit that detects your hardware and guides you through
optimizing Pop!\_OS for development, AI/ML, gaming, and robotics workloads.

[Quick Start](#-quick-start) · [Modules](#-modules) · [Hardware](#-reference-hardware) · [Documentation](#-documentation)

</div>

---

## ⚡ Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/pop-os-linux-optimisation.git
cd pop-os-linux-optimisation

# Make scripts executable
chmod +x install.sh scripts/*.sh

# Launch the interactive installer
./install.sh
```

The installer will **automatically detect your hardware** (CPU, GPU, RAM, laptop model) and provide tailored recommendations for your specific machine.

### CLI Options

```bash
./install.sh --help          # Show all options
./install.sh --dry-run       # Preview without installing
./install.sh --dev --ai      # Install specific modules only
./install.sh --all           # Install everything (non-interactive)
```

---

## 📦 Modules

| Module | Description | Script |
|--------|-------------|--------|
| **Developer Tools** | Git, Python, Node.js, Rust, Docker, editors, terminal utilities | `scripts/dev-setup.sh` |
| **AI / ML Workstation** | Ollama, LLMs, CUDA, PyTorch, Jupyter, Open WebUI | `scripts/ai-setup.sh` |
| **Gaming** | Steam, Proton, Lutris, GameMode, MangoHud, GPU passthrough | `scripts/gaming-setup.sh` |
| **Robotics Lab** | ROS 2 Humble, SLAM, Gazebo, Nav2, Arduino, MoveIt 2 | `scripts/robotics-setup.sh` |
| **SSH Configuration** | Key generation, agent, GitHub/GitLab, server hardening | `scripts/ssh-setup.sh` |
| **System Optimization** | Power profiles, thermals, SSD, zRAM, kernel tuning | `scripts/system-optimize.sh` |

Each module presents an **interactive checklist** where you select exactly which packages to install. Nothing is forced — you're always in control.

---

## 🖥 Reference Hardware

This toolkit is developed and tested on a **Lenovo ThinkPad P-Series workstation laptop** running Pop!\_OS. Hardware detection adapts recommendations automatically for other machines.

### System Specifications

| Component | Specification | Notes |
|-----------|--------------|-------|
| **Laptop** | Lenovo ThinkPad P-Series | Mobile workstation, ISV-certified |
| **CPU** | Intel Core i9-13950HX | 24 cores (8P + 16E), 32 threads, up to 5.4 GHz |
| **GPU** | NVIDIA RTX A1000 6GB | Ampere architecture, CUDA 8.6, workstation-class |
| **RAM** | 32 GB DDR5 | Dual-channel |
| **Storage** | 1 TB NVMe SSD | PCIe Gen4 |
| **OS** | Pop!\_OS 22.04 LTS | NVIDIA ISO, systemd-boot, system76-power |

### CPU — Intel Core i9-13950HX

A 13th-generation Raptor Lake mobile workstation processor with hybrid architecture.

- **8 Performance cores** (Hyper-Threaded) for heavy single/multi-threaded workloads
- **16 Efficiency cores** for background tasks and power saving
- **36 MB Intel Smart Cache**
- Excellent for: compilation, AI training, VM hosting, and multi-threaded builds

### GPU — NVIDIA RTX A1000 (6 GB VRAM)

A professional-grade Ampere GPU with workstation certifications (ISV-certified drivers).

| Workload | Capability |
|----------|-----------|
| CUDA / AI Inference | Runs 3B–7B parameter models (quantized) locally |
| Blender / CAD | Hardware ray tracing, certified drivers |
| Gaming | Medium–High settings at 1080p via Proton/Steam |
| Computer Vision | OpenCV + YOLO real-time inference |
| Video Encoding | NVENC hardware encoding |

### RAM — 32 GB DDR5

Sufficient for simultaneous workloads:
- Docker containers + IDE + browser + AI model inference
- Virtual machines (8–12 GB allocation for Windows VM)
- ROS 2 Gazebo simulation + RViz visualization

### Storage — 1 TB NVMe SSD

Optimized via TRIM scheduling and I/O tuning (see System Optimization module).

---

## 🗂 Project Structure

```
pop-os-linux-optimisation/
├── install.sh                  # Master interactive installer (entry point)
├── lib/
│   └── common.sh               # Shared TUI library (colors, menus, detection)
├── scripts/
│   ├── dev-setup.sh             # Developer tools installer
│   ├── ai-setup.sh              # AI/ML workstation installer
│   ├── gaming-setup.sh          # Gaming optimization installer
│   ├── robotics-setup.sh        # Robotics lab installer (ROS 2)
│   ├── ssh-setup.sh             # SSH key & server configuration
│   └── system-optimize.sh       # System performance tuning
├── dev-tools/
│   └── dev-setup.sh             # Legacy script (see scripts/)
├── ai/
│   └── README.md                # AI/ML documentation
├── gaming/
│   └── README.md                # Gaming documentation
├── robotics/
│   └── README.md                # Robotics documentation
└── README.md                    # This file
```

---

## 🔧 Recommended Configurations

### Daily Workstation

Standard development workflow with local AI capabilities.

```
Modules: Developer Tools + SSH + System Optimization
Power:   Balanced
Usage:   Ollama running, VS Code, Docker, Arduino IDE
```

### AI Research Mode

Heavy local LLM inference and model experimentation.

```
Modules: AI/ML Workstation + Developer Tools
Power:   Performance
Usage:   Ollama + Open WebUI, Jupyter, PyTorch, CUDA
Memory:  ~24 GB available for models (after OS)
```

### Robotics Development

ROS 2 with simulation, navigation, and embedded systems.

```
Modules: Robotics Lab + Developer Tools
Power:   Performance
Usage:   ROS 2, Gazebo, RViz, SLAM, Arduino
```

### Gaming Mode

Native Linux gaming with optional Windows VM passthrough.

```
Modules: Gaming + System Optimization
Power:   Performance
Usage:   Steam + Proton, GameMode + MangoHud
```

---

## 📖 Documentation

Detailed guides for each module:

- [**AI/ML Workstation Guide**](ai/README.md) — Ollama, model selection by GPU, Open WebUI, Python ML stack
- [**Gaming Optimization Guide**](gaming/README.md) — Steam, Proton, GPU passthrough (Pop!\_OS specific)
- [**Robotics Lab Guide**](robotics/README.md) — ROS 2 Humble, SLAM, Gazebo, Arduino bridge

---

## ⚠️ Pop!\_OS Specific Notes

This toolkit is designed specifically for **Pop!\_OS 22.04 LTS** and accounts for its differences from standard Ubuntu:

| Feature | Pop!\_OS | Ubuntu |
|---------|---------|--------|
| **Bootloader** | systemd-boot | GRUB |
| **Boot params** | `kernelstub -a "param"` | `/etc/default/grub` |
| **Power mgmt** | system76-power | TLP / power-profiles-daemon |
| **NVIDIA drivers** | Pre-installed (NVIDIA ISO) | Manual PPA or .run |
| **Desktop** | COSMIC (GNOME fork) | GNOME |
| **Recovery** | Built-in refresh/reinstall | Manual |

> **Important:** Do not use `update-grub` on Pop!\_OS. Boot parameters are managed via `kernelstub`. The scripts in this toolkit handle this automatically.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/improvement`
3. Commit changes: `git commit -m "Add feature"`
4. Push: `git push origin feature/improvement`
5. Open a Pull Request

---

## 📄 License

This project is open source under the [MIT License](LICENSE).