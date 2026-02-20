### Robotics Lab Setup (ROS + SLAM)
We’ll install:
- ROS 2
- SLAM
- Simulation
- Arduino bridge

### Install ROS 2 (Humble — stable)
```
sudo apt install software-properties-common
sudo add-apt-repository universe
sudo apt update

sudo apt install ros-humble-desktop -y
```

### Source ROS automatically
```
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

### Robotics essentials
```
sudo apt install -y \
ros-humble-navigation2 \
ros-humble-slam-toolbox \
ros-humble-turtlebot3 \
ros-humble-rviz2 \
ros-humble-gazebo-ros
```

### Arduino ↔ ROS bridge
```
pip install pyserial
```

### SLAM test (simulation)
```
export TURTLEBOT3_MODEL=burger
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```
Then:
```
ros2 launch turtlebot3_slam slam.launch.py
```
You’ll see live mapping in RViz

### Why this matters to you
This directly supports your project like:
- AI assistive navigation for the blind
- You now have:
- Real-time mapping
- Sensor fusion
- Navigation stack