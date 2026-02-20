# Robotics Lab Guide (ROS 2 Humble)

> Full robotics development environment with SLAM, simulation, navigation, and embedded systems.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Setup (Script)](#quick-setup-script)
- [ROS 2 Humble Installation](#ros-2-humble-installation)
- [Navigation 2 & SLAM](#navigation-2--slam)
- [Gazebo Simulation](#gazebo-simulation)
- [TurtleBot3 — SLAM Demo](#turtlebot3--slam-demo)
- [Arduino & Embedded Bridge](#arduino--embedded-bridge)
- [Computer Vision](#computer-vision)
- [MoveIt 2 — Motion Planning](#moveit-2--motion-planning)
- [ROS 2 Workspace Setup](#ros-2-workspace-setup)
- [Practical Applications](#practical-applications)
- [Troubleshooting](#troubleshooting)

---

## Overview

This module configures a complete robotics development stack:

| Component | Version | Purpose |
|-----------|---------|---------|
| **ROS 2** | Humble Hawksbill (LTS) | Robot framework, messaging, tools |
| **Navigation 2** | Nav2 | Autonomous navigation stack |
| **SLAM Toolbox** | — | Simultaneous Localization and Mapping |
| **Gazebo Classic** | 11 | 3D robotics simulation |
| **MoveIt 2** | — | Robotic arm motion planning |
| **TurtleBot3** | — | Reference platform for learning |
| **Arduino CLI** | Latest | Microcontroller programming |
| **PlatformIO** | Latest | Embedded development platform |

### Target Platform

- **OS:** Pop!\_OS 22.04 LTS (Ubuntu 22.04 Jammy base)
- **ROS 2:** Humble Hawksbill — the current LTS release for `jammy`
- **Reference:** [ROS 2 Humble Documentation](https://docs.ros.org/en/humble/)

---

## Prerequisites

- Lenovo ThinkPad P-Series (or any Ubuntu 22.04-based system)
- Pop!\_OS 22.04 LTS (`lsb_release -cs` should output `jammy`)
- At least 20 GB free disk space
- GPU recommended for Gazebo simulation (NVIDIA with proprietary drivers)
- Internet connection for package downloads

---

## Quick Setup (Script)

The interactive script installs everything with selectable components:

```bash
cd pop-os-linux-optimisation
chmod +x scripts/robotics-setup.sh
./scripts/robotics-setup.sh
```

Or from the master installer:

```bash
./install.sh --robotics
```

---

## ROS 2 Humble Installation

### Step 1: Set Up ROS 2 Repository

```bash
# Install prerequisites
sudo apt install -y software-properties-common curl gnupg lsb-release

# Add the ROS 2 GPG key
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg

# Add the repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu jammy main" | \
    sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Enable universe repository
sudo add-apt-repository -y universe
sudo apt update
```

### Step 2: Install ROS 2 Desktop

```bash
sudo apt install -y ros-humble-desktop ros-humble-ros-base ros-dev-tools
```

### Step 3: Source ROS 2 Automatically

```bash
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

### Step 4: Initialize rosdep

```bash
sudo rosdep init
rosdep update
```

### Step 5: Verify Installation

```bash
# In Terminal 1
ros2 run demo_nodes_cpp talker

# In Terminal 2
ros2 run demo_nodes_py listener
```

You should see the talker publishing messages and the listener receiving them.

---

## Navigation 2 & SLAM

The Navigation 2 stack provides autonomous robot navigation capabilities.

### Install Packages

```bash
sudo apt install -y \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-slam-toolbox \
    ros-humble-robot-localization \
    ros-humble-cartographer \
    ros-humble-cartographer-ros
```

### Key Components

| Package | Purpose |
|---------|---------|
| `navigation2` | Behavior trees, planners, controller server |
| `nav2-bringup` | Launch files for Nav2 stack |
| `slam-toolbox` | Online/offline SLAM |
| `cartographer` | Google's 2D/3D SLAM (lidar-based) |
| `robot-localization` | EKF/UKF sensor fusion for odometry |

### Architecture

```
Sensors (LiDAR, IMU, cameras)
       ↓
   SLAM Toolbox  →  Map (OccupancyGrid)
       ↓
  robot_localization  →  Robot Pose (TF)
       ↓
  Nav2 Planner  →  Global Path
       ↓
  Nav2 Controller  →  Velocity Commands (cmd_vel)
       ↓
    Motor Driver
```

---

## Gazebo Simulation

Gazebo provides physics-based 3D simulation for testing robot algorithms without hardware.

### Install

```bash
sudo apt install -y \
    ros-humble-gazebo-ros \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-gazebo-plugins \
    ros-humble-gazebo-ros2-control
```

### Test Gazebo

```bash
gazebo --verbose
```

A window should open with the Gazebo simulation environment.

---

## TurtleBot3 — SLAM Demo

TurtleBot3 is the reference robot platform for learning ROS 2.

### Install

```bash
sudo apt install -y \
    ros-humble-turtlebot3 \
    ros-humble-turtlebot3-simulations \
    ros-humble-turtlebot3-navigation2 \
    ros-humble-turtlebot3-cartographer \
    ros-humble-turtlebot3-teleop

# Set the default robot model
echo 'export TURTLEBOT3_MODEL=burger' >> ~/.bashrc
source ~/.bashrc
```

### Run SLAM Demo (Three Terminals)

**Terminal 1 — Launch simulation world:**

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

**Terminal 2 — Launch SLAM (Cartographer):**

```bash
ros2 launch turtlebot3_cartographer cartographer.launch.py use_sim_time:=True
```

**Terminal 3 — Teleoperate the robot:**

```bash
ros2 run turtlebot3_teleop teleop_keyboard
```

Use `W/A/S/D/X` keys to drive the robot. Watch the map build in real-time in RViz.

### Save the Map

```bash
ros2 run nav2_map_server map_saver_cli -f ~/my_map
```

This creates `my_map.yaml` and `my_map.pgm` files.

---

## Arduino & Embedded Bridge

Connect microcontrollers to ROS 2 for sensor integration and actuator control.

### Install Arduino CLI

```bash
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
```

### Install PlatformIO

```bash
pip install platformio
```

### Serial Port Access

```bash
# Add user to dialout group
sudo usermod -aG dialout $USER
# Log out and back in for changes to take effect
```

### Python Serial Bridge (ROS 2 ↔ Arduino)

```python
#!/usr/bin/env python3
"""Simple ROS 2 node that reads serial data from Arduino."""

import rclpy
from rclpy.node import Node
from std_msgs.msg import String
import serial

class ArduinoBridge(Node):
    def __init__(self):
        super().__init__('arduino_bridge')
        self.publisher = self.create_publisher(String, 'arduino/data', 10)
        self.serial = serial.Serial('/dev/ttyUSB0', 9600, timeout=1)
        self.timer = self.create_timer(0.1, self.read_serial)

    def read_serial(self):
        if self.serial.in_waiting > 0:
            line = self.serial.readline().decode('utf-8').strip()
            msg = String()
            msg.data = line
            self.publisher.publish(msg)
            self.get_logger().info(f'Arduino: {line}')

def main():
    rclpy.init()
    node = ArduinoBridge()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
```

### Micro-ROS (Alternative)

For tighter ROS 2 integration with microcontrollers (ESP32, STM32, Pico):

```bash
sudo apt install -y ros-humble-micro-ros-agent
# Then flash micro-ROS firmware to your microcontroller
```

---

## Computer Vision

### ROS 2 CV Packages

```bash
sudo apt install -y \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    ros-humble-image-transport-plugins \
    ros-humble-vision-opencv \
    ros-humble-image-pipeline \
    ros-humble-depth-image-proc
```

### Python OpenCV + YOLO

```bash
pip install opencv-python ultralytics
```

### Example: Camera → ROS 2 Topic

```python
#!/usr/bin/env python3
"""Publish camera frames to ROS 2 with YOLO detection."""

import cv2
from ultralytics import YOLO
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
from cv_bridge import CvBridge

class VisionNode(Node):
    def __init__(self):
        super().__init__('vision_node')
        self.publisher = self.create_publisher(Image, 'camera/image', 10)
        self.bridge = CvBridge()
        self.model = YOLO('yolov8n.pt')
        self.cap = cv2.VideoCapture(0)
        self.timer = self.create_timer(1/30, self.process_frame)

    def process_frame(self):
        ret, frame = self.cap.read()
        if ret:
            results = self.model(frame, verbose=False)
            annotated = results[0].plot()
            msg = self.bridge.cv2_to_imgmsg(annotated, encoding='bgr8')
            self.publisher.publish(msg)

def main():
    rclpy.init()
    node = VisionNode()
    rclpy.spin(node)
    rclpy.shutdown()
```

---

## MoveIt 2 — Motion Planning

MoveIt 2 provides motion planning, kinematics, and collision detection for robotic arms.

```bash
sudo apt install -y \
    ros-humble-moveit \
    ros-humble-moveit-configs-utils \
    ros-humble-moveit-ros-visualization
```

Tutorial: [MoveIt 2 Getting Started](https://moveit.picknik.ai/humble/doc/tutorials/getting_started/getting_started.html)

---

## ROS 2 Workspace Setup

Create a workspace for your custom packages:

```bash
# Create workspace
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws

# Source ROS 2
source /opt/ros/humble/setup.bash

# Build (empty workspace)
colcon build --symlink-install

# Source workspace
echo "source ~/ros2_ws/install/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

### Create a New Package

```bash
cd ~/ros2_ws/src
ros2 pkg create --build-type ament_python my_robot_pkg --dependencies rclpy std_msgs
cd ~/ros2_ws
colcon build --packages-select my_robot_pkg
```

### Essential Dev Tools

```bash
sudo apt install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool
```

---

## Practical Applications

This setup directly supports projects like:

### AI-Assistive Navigation for the Blind

- **SLAM** for real-time environment mapping
- **Nav2** for path planning and obstacle avoidance
- **Computer Vision** for object detection and scene understanding
- **Arduino bridge** for haptic feedback and sensor integration
- **Ollama/AI** for natural language scene descriptions

### Autonomous Mobile Robots

- **Nav2 + SLAM** for autonomous navigation
- **Gazebo** for testing before hardware deployment
- **LiDAR + camera fusion** for robust perception

### Robotic Arms

- **MoveIt 2** for motion planning
- **Gazebo** for virtual pick-and-place testing
- **Micro-ROS** for gripper control

---

## Troubleshooting

### ROS 2 commands not found

```bash
source /opt/ros/humble/setup.bash
# Add to ~/.bashrc if not already there
```

### Gazebo crashes or black screen

```bash
# Check GPU driver
nvidia-smi
# Try with software rendering
LIBGL_ALWAYS_SOFTWARE=1 gazebo --verbose
```

### rosdep errors

```bash
sudo rosdep init     # Only run once
rosdep update
rosdep install --from-paths src --ignore-src -y
```

### Serial port permission denied

```bash
sudo usermod -aG dialout $USER
# Log out and back in
ls -la /dev/ttyUSB0   # Verify device exists
```

### colcon build fails

```bash
# Clean build artifacts
rm -rf build/ install/ log/
# Rebuild
colcon build --symlink-install 2>&1 | tee build.log
```

---

## Further Reading

- [ROS 2 Humble Documentation](https://docs.ros.org/en/humble/)
- [Navigation 2 Documentation](https://navigation.ros.org/)
- [Gazebo Classic Tutorials](https://classic.gazebosim.org/tutorials)
- [MoveIt 2 Tutorials](https://moveit.picknik.ai/humble/)
- [TurtleBot3 Manual](https://emanual.robotis.com/docs/en/platform/turtlebot3/overview/)
- [micro-ROS Documentation](https://micro.ros.org/)
- [Arduino CLI Reference](https://arduino.github.io/arduino-cli/)
- [PlatformIO Documentation](https://docs.platformio.org/)
