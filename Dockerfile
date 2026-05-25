# ---------------------------------------------------------------------------
# RealSense D4xx + ROS 2 Jazzy — NVIDIA GPU + GUI
#
# Approach (from 2b-t/realsense-ros2-docker):
#   Install ros-jazzy-librealsense2* and ros-jazzy-realsense2-* from the
#   ROS apt repo.  This keeps SDK and ROS wrapper version-matched without
#   needing Intel's own apt repo (which has recurring GPG key issues).
#
# USB high throughput:
#   The kernel usbfs memory limit (default 16 MB) must be raised on the HOST
#   before starting the container.  The entrypoint reminds you if it is low.
#   To raise permanently:
#     echo 'options usbcore usbfs_memory_mb=1000' | sudo tee /etc/modprobe.d/usbcore.conf
#     sudo update-initramfs -u
#   To raise for the current session only:
#     sudo sh -c 'echo 1000 > /sys/module/usbcore/parameters/usbfs_memory_mb'
#
# NVIDIA:
#   The NVIDIA container runtime injects GPU drivers at run time — no CUDA
#   base image is needed.  OpenGL (for RViz2) is provided via
#   NVIDIA_DRIVER_CAPABILITIES=graphics.
# ---------------------------------------------------------------------------
FROM ros:jazzy-perception

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    ROS_DISTRO=jazzy

# ── 1. Base utilities ────────────────────────────────────────────────────── #
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        curl \
        gnupg2 \
        lsb-release \
        usbutils \
        v4l-utils \
        python3-pip \
        python3-colcon-common-extensions \
        nano \
        less \
    && rm -rf /var/lib/apt/lists/*

# ── 2. RealSense SDK + ROS 2 wrapper (version-matched via ROS apt) ────────── #
# ros-jazzy-librealsense2   — the SDK shared library
# ros-jazzy-realsense2-*    — ROS2 camera driver + description + msgs
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-librealsense2 \
        ros-${ROS_DISTRO}-realsense2-camera \
        ros-${ROS_DISTRO}-realsense2-description \
        ros-${ROS_DISTRO}-realsense2-camera-msgs \
    && rm -rf /var/lib/apt/lists/*

# ── 3. Visualisation & diagnostics ─────────────────────────────────────────── #
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-rviz2 \
        ros-${ROS_DISTRO}-rqt \
        ros-${ROS_DISTRO}-rqt-image-view \
        ros-${ROS_DISTRO}-rqt-graph \
        ros-${ROS_DISTRO}-image-transport-plugins \
        ros-${ROS_DISTRO}-compressed-image-transport \
    && rm -rf /var/lib/apt/lists/*

# ── 4. DDS config — localhost-only (no multicast flooding on lab network) ─── #
# reuse the CycloneDDS profile pattern from the rest of this workspace
RUN mkdir -p /dds_profiles
COPY dds_profiles/ /dds_profiles/
ENV CYCLONEDDS_URI="file:///dds_profiles/cyclonedds_profile.xml" \
    RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Shell environment ─────────────────────────────────────────────────── #
# ROS_DOMAIN_ID and ROS_AUTOMATIC_DISCOVERY_RANGE come from the container ENV
# (set by docker-compose / .env) so they can be overridden without rebuilding.
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash"  >> /root/.bashrc \
 && echo "export RCUTILS_COLORIZED_OUTPUT=1"         >> /root/.bashrc \
 && echo "# Auto-refresh the ROS 2 graph daemon on every new shell so" >> /root/.bashrc \
 && echo "# ros2 topic list is always current and never shows a stale cache." >> /root/.bashrc \
 && echo "ros2 daemon stop &>/dev/null; ros2 daemon start &>/dev/null" >> /root/.bashrc

# ── 6. Entrypoint — checks USB memory and camera visibility at startup ────── #
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /ros2_ws
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
