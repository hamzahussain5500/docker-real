#!/bin/bash
# entrypoint.sh — startup checks for USB throughput and camera visibility

source /opt/ros/jazzy/setup.bash

# ── USB memory buffer check ────────────────────────────────────────────── #
USB_MEM=$(cat /sys/module/usbcore/parameters/usbfs_memory_mb 2>/dev/null || echo 0)
if [ "${USB_MEM}" -lt 200 ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│  WARNING: usbfs_memory_mb = ${USB_MEM} MB  (recommended ≥ 200 MB)        │"
    echo "│  RealSense depth at high resolution may drop frames.            │"
    echo "│  Fix on the HOST before starting this container:                │"
    echo "│    sudo sh -c 'echo 1000 > /sys/module/usbcore/parameters/usbfs_memory_mb'  │"
    echo "│  Permanently:                                                   │"
    echo "│    echo 'options usbcore usbfs_memory_mb=1000' |               │"
    echo "│      sudo tee /etc/modprobe.d/usbcore.conf && sudo update-initramfs -u │"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo ""
fi

# ── Camera device check ────────────────────────────────────────────────── #
if ls /dev/video* >/dev/null 2>&1; then
    echo "[realsense] Video devices found: $(ls /dev/video* | tr '\n' ' ')"
else
    echo "[realsense] WARNING: No /dev/video* devices found."
    echo "            Make sure the camera is plugged in via USB 3.0+ and"
    echo "            the container was started with the correct device rules."
fi

if ls /dev/bus/usb >/dev/null 2>&1; then
    INTEL=$(lsusb 2>/dev/null | grep -i "8086\|Intel.*RealSense\|8087:0032\|8087:0033" | head -3)
    if [ -n "${INTEL}" ]; then
        echo "[realsense] Intel USB device detected:"
        echo "            ${INTEL}"
    else
        echo "[realsense] No Intel RealSense USB device found on bus."
    fi
fi

echo ""
echo "──────────────────────────────────────────────"
echo "  RealSense ROS 2 container ready (Jazzy)"
echo "  Quick launch:"
echo "    ros2 launch realsense2_camera rs_launch.py"
echo "  With IMU:"
echo "    ros2 launch realsense2_camera rs_launch.py enable_gyro:=true enable_accel:=true unite_imu_method:=2"
echo "──────────────────────────────────────────────"
echo ""

exec "$@"
