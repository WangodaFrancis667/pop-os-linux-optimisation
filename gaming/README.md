# Gaming Optimization Guide

> Configure Pop!\_OS for the best Linux gaming experience — native, Proton, and GPU passthrough.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Setup (Script)](#quick-setup-script)
- [Steam & Proton](#steam--proton)
- [Performance Tools](#performance-tools)
- [Lutris & Heroic](#lutris--heroic)
- [Vulkan & Drivers](#vulkan--drivers)
- [GPU Passthrough (KVM)](#gpu-passthrough-kvm)
- [Launch Options](#launch-options-cheat-sheet)
- [Troubleshooting](#troubleshooting)

---

## Overview

Linux gaming has evolved significantly. This guide covers three approaches:

| Approach | Performance | Compatibility | Complexity |
|----------|------------|---------------|------------|
| **Native Linux** | 100% | Limited catalog | Easy |
| **Proton / Wine** | 90–100% | Thousands of titles | Easy |
| **GPU Passthrough VM** | 95–98% | Near-full Windows | Advanced |

With the **RTX A1000 6 GB**, expect medium–high settings at 1080p for most titles via Proton.

---

## Prerequisites

- Lenovo ThinkPad P-Series (or any NVIDIA-equipped laptop)
- Pop!\_OS 22.04 LTS (NVIDIA ISO for pre-installed drivers)
- NVIDIA driver installed and working (`nvidia-smi`)
- Vulkan support (`vulkaninfo`)
- 32 GB RAM (recommended for VM passthrough)

---

## Quick Setup (Script)

The interactive script handles everything:

```bash
cd pop-os-linux-optimisation
chmod +x scripts/gaming-setup.sh
./scripts/gaming-setup.sh
```

Or from the master installer:

```bash
./install.sh --gaming
```

---

## Steam & Proton

### Install Steam

```bash
sudo apt install -y steam-installer
```

### Enable Proton (Steam Play)

1. Open **Steam → Settings → Compatibility**
2. Check **"Enable Steam Play for supported titles"**
3. Check **"Enable Steam Play for all other titles"**
4. Select **Proton Experimental** (or GE-Proton via ProtonUp-Qt)

### Install ProtonUp-Qt

Manage custom Proton versions (GE-Proton has more game fixes than Valve's default):

```bash
flatpak install -y flathub net.davidotek.pupgui2
```

Launch **ProtonUp-Qt** and install the latest **GE-Proton** version.

### Check Game Compatibility

Before purchasing, check [ProtonDB](https://www.protondb.com/) for Linux compatibility ratings.

---

## Performance Tools

### GameMode

Dynamically optimizes CPU governor, I/O priority, and GPU clocks when a game is running.

```bash
sudo apt install -y gamemode
```

Verify: `gamemoded -t`

### MangoHud

Real-time FPS counter, GPU/CPU stats, and frame timing overlay.

```bash
sudo apt install -y mangohud
```

Configuration file at `~/.config/MangoHud/MangoHud.conf`:

```ini
# Key metrics
position=top-left
font_size=20
fps
frametime
gpu_stats
gpu_temp
cpu_stats
cpu_temp
ram
vram
frame_timing
```

### Using Both Together

Set Steam launch options per game (right-click → Properties → Launch Options):

```
gamemoderun mangohud %command%
```

---

## Lutris & Heroic

### Lutris — Universal Game Platform

Manages Wine prefixes, runners, and install scripts for non-Steam games.

```bash
sudo add-apt-repository -y ppa:lutris-team/lutris
sudo apt update && sudo apt install -y lutris
```

Supports: GOG, Epic, Ubisoft, Battle.net, and standalone titles.

### Heroic Games Launcher

Native Epic Games Store and GOG Galaxy launcher for Linux.

```bash
flatpak install -y flathub com.heroicgameslauncher.hgl
```

---

## Vulkan & Drivers

Vulkan is essential for Proton/DXVK (translates DirectX 11/12 to Vulkan).

```bash
# Enable 32-bit architecture (required for many games)
sudo dpkg --add-architecture i386
sudo apt update

# Install Vulkan stack
sudo apt install -y \
    vulkan-tools \
    mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
    libvulkan1 libvulkan1:i386
```

Verify:

```bash
vulkaninfo --summary     # Should show your NVIDIA GPU
vkcube                   # Spinning Vulkan cube test
```

---

## GPU Passthrough (KVM)

> **Advanced:** Run Windows in a VM with near-native GPU performance for games that won't work in Proton.

### Requirements

| Requirement | Lenovo ThinkPad P-Series |
|-------------|-------------|
| CPU virtualization (VT-x/VT-d) | Intel i9-13950HX ✓ (enable in Lenovo BIOS → Security) |
| IOMMU support | Required — enable in Lenovo BIOS → Security → Virtualization |
| Two GPUs (iGPU + dGPU) | Intel UHD 770 + RTX A1000 ✓ |
| RAM | 32 GB DDR5 ✓ (allocate 8–12 GB to VM) |

### Step 1: Install KVM / QEMU

```bash
sudo apt install -y qemu-kvm libvirt-daemon-system \
    libvirt-clients virt-manager ovmf bridge-utils

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

> Log out and back in for group changes to take effect.

### Step 2: Check IOMMU Support

```bash
dmesg | grep -i -E "DMAR|IOMMU"
```

If no output, IOMMU may need to be enabled in BIOS (Intel VT-d).

### Step 3: Enable IOMMU Boot Parameter

> **⚠️ Pop!\_OS uses systemd-boot, not GRUB.** Use `kernelstub`, not `update-grub`.

```bash
# Intel CPU — use intel_iommu
sudo kernelstub -a "intel_iommu=on"
sudo kernelstub -a "iommu=pt"
```

For AMD CPUs:

```bash
sudo kernelstub -a "amd_iommu=on"
sudo kernelstub -a "iommu=pt"
```

**Reboot** and verify:

```bash
dmesg | grep -i iommu
# Should show "IOMMU enabled"
```

### Step 4: Identify IOMMU Groups

```bash
#!/bin/bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done
```

Your NVIDIA GPU and its audio device should be in the same IOMMU group and **separate** from other devices.

### Step 5: Configure VFIO

Find your GPU PCI IDs:

```bash
lspci -nn | grep NVIDIA
# Example output: 01:00.0 3D controller [0302]: NVIDIA Corporation ... [10de:XXXX]
```

Add VFIO driver binding:

```bash
sudo kernelstub -a "vfio-pci.ids=10de:XXXX,10de:YYYY"
```

Replace `XXXX` and `YYYY` with your GPU and audio device IDs.

### Step 6: Create Windows VM

1. Open **virt-manager**
2. Create new VM → **Local install media (ISO)**
3. Select Windows 11 ISO
4. Allocate **8–12 GB RAM** and **6–8 CPU cores**
5. Use **UEFI firmware** (OVMF)
6. Add PCI passthrough for your NVIDIA GPU

### Performance Tips

- Use **VirtIO** drivers for disk and network (download [VirtIO ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/))
- Pin CPU cores to the VM for consistent performance
- Use **hugepages** for memory performance
- Install the guest NVIDIA driver inside Windows

---

## Launch Options Cheat Sheet

Use these in Steam (right-click → Properties → Launch Options):

| Option | Purpose |
|--------|---------|
| `gamemoderun %command%` | Enable GameMode optimizations |
| `mangohud %command%` | Show performance overlay |
| `gamemoderun mangohud %command%` | Both together |
| `PROTON_USE_WINED3D=1 %command%` | Force OpenGL (instead of Vulkan/DXVK) |
| `DXVK_HUD=fps %command%` | Show DXVK FPS counter |
| `PROTON_NO_ESYNC=1 %command%` | Disable esync (fix some crashes) |
| `PROTON_NO_FSYNC=1 %command%` | Disable fsync |
| `SteamDeck=1 %command%` | Force Steam Deck compatibility mode |

---

## Troubleshooting

### Game won't launch via Proton

```bash
# Check Proton logs
cat ~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx/drive_c/users/steamuser/Temp/*.log

# Try different Proton version (GE-Proton often fixes issues)
# Check ProtonDB for game-specific tweaks
```

### Poor FPS

1. Verify GPU is being used (MangoHud shows GPU load)
2. Check power profile: `system76-power profile performance`
3. Enable GameMode: `gamemoderun`
4. Check compositing: disable desktop effects during gaming

### Vulkan not working

```bash
vulkaninfo --summary     # Check for errors
sudo apt install --reinstall mesa-vulkan-drivers
```

### Steam not finding games on secondary drive

```bash
# Add library folder in Steam → Settings → Storage
# Ensure the drive is mounted in /etc/fstab with proper permissions
```

---

## Further Reading

- [ProtonDB — Game Compatibility](https://www.protondb.com/)
- [Lutris Wiki](https://github.com/lutris/docs)
- [Arch Wiki: PCI Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Steam Deck Proton FAQ](https://partner.steamgames.com/doc/steamdeck/proton)
- [Pop!\_OS: systemd-boot Configuration](https://support.system76.com/articles/kernelstub/)
- [MangoHud Configuration](https://github.com/flightlessmango/MangoHud)