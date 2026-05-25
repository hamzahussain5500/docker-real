# RealSense ROS 2 Docker — Jazzy + NVIDIA + GUI

Containerised Intel RealSense D4xx camera with ROS 2 Jazzy, NVIDIA GPU
support, X11 GUI (RViz2, rqt), and USB high-throughput configuration.

Based on the [2b-t/realsense-ros2-docker](https://github.com/2b-t/realsense-ros2-docker)
approach: all packages come from the ROS apt repo (`ros-jazzy-realsense2-*`)
so the librealsense SDK and ROS wrapper are always version-matched.

---

## Folder layout

```
docker-real/
├── Dockerfile
├── docker-compose.yml
├── .env
├── entrypoint.sh          startup checks (USB memory, camera visibility)
├── dds_profiles/
│   └── cyclonedds_profile.xml   localhost-only DDS (no lab network flooding)
├── bags/                  rosbag output (bind-mounted, persists on host)
└── README.md
```

---

## Prerequisites

### 1. USB high-throughput (required for depth at full resolution)

The Linux kernel's `usbfs` memory limit defaults to 16 MB.  RealSense depth
streams at 1280×720 30 fps need ~200 MB.  Set it on the **host**:

```bash
# current session
sudo sh -c 'echo 1000 > /sys/module/usbcore/parameters/usbfs_memory_mb'

# permanent (survives reboot)
echo 'options usbcore usbfs_memory_mb=1000' \
  | sudo tee /etc/modprobe.d/usbcore.conf
sudo update-initramfs -u
```

### 2. NVIDIA Container Toolkit

```bash
# check it is installed
nvidia-smi   # must work on the host
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
```

If the second command fails, install the toolkit:
```bash
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 3. X11 access

```bash
xhost +local:docker
```

---

## Build and run

```bash
cd docker-real
docker compose build          # ~5 min first time

xhost +local:docker           # allow X11
docker compose up -d          # start container
docker exec -it realsense bash
```

---

## Camera verification

```bash
# inside container
rs-enumerate-devices -s        # list all streams including IMU
ros2 run realsense2_camera realsense2_camera_node -- --ros-args -p enable_color:=true
ros2 topic list | grep camera
```

---

## Common launch commands

```bash
# Colour + depth
ros2 launch realsense2_camera rs_launch.py

# IMU only (Allan Variance recording)
ros2 launch realsense2_camera rs_launch.py \
    enable_gyro:=true \
    enable_accel:=true \
    unite_imu_method:=2 \
    enable_color:=false \
    enable_depth:=false

# Full streams
ros2 launch realsense2_camera rs_launch.py \
    enable_color:=true \
    enable_depth:=true \
    enable_gyro:=true \
    enable_accel:=true \
    unite_imu_method:=2 \
    pointcloud.enable:=true

# RViz2 visualisation
rviz2 -d /opt/ros/jazzy/share/realsense2_description/rviz/urdf.rviz
```

## Record a bag (for Allan Variance)

```bash
ros2 bag record \
    /camera/imu \
    /camera/accel/sample \
    /camera/gyro/sample \
    -o /root/bags/imu_$(date +%Y%m%d_%H%M%S) \
    --max-bag-duration 300
```

Bags are saved to `docker-real/bags/` on the host.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `No /dev/video*` | Camera not plugged in, or USB 3.0 port not used |
| Frames dropping at high resolution | Raise `usbfs_memory_mb` (see Prerequisites) |
| NVIDIA error in RViz2 | Run `xhost +local:docker` before `docker compose up` |
| IMU topic silent | Set `enable_gyro:=true enable_accel:=true unite_imu_method:=2`; keep depth enabled |
| DDS errors | Check `net.core.rmem_max` ≥ 2097152 on host |
