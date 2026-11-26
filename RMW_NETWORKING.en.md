**[English](./RMW_NETWORKING.en.md)** | [Français](./RMW_NETWORKING.md)

# ROS 2 Middleware (RMW) Guide: macOS, Simulation & Real Robot (Raspberry Pi)

In **ROS 2 Jazzy**, inter-node communication relies on an abstraction layer called **RMW** (*ROS Middleware*). Choosing and properly configuring the RMW determines both simulation stability on macOS (Webots, RViz2, Nav2) and the reliability of the Wi-Fi link with the real car (Raspberry Pi running Ubuntu Server).

---

## 1. Comparison of the 3 Middlewares Available in ROS 2 Jazzy

| Middleware | `RMW_IMPLEMENTATION` Variable | Strengths | Limitations & Pitfalls |
| :--- | :--- | :--- | :--- |
| **FastDDS** *(Ubuntu default)* | `rmw_fastrtps_cpp` | Installed by default on Ubuntu; works out of the box on simple wired networks. | **Unstable on macOS** with large node graphs or heavy sensors (LiDAR/camera) due to POSIX shared-memory leaks and port limits in `LOCALHOST` mode. |
| **CycloneDDS** *(recommended for DDS)* | `rmw_cyclonedds_cpp` | Very fast and lightweight; bypasses macOS shared-memory bugs via an XML profile (`lo0` / `en0`); **interoperable with FastDDS** over the network. | Like any DDS implementation, it relies on **UDP multicast**, which is often throttled or blocked by public or competition Wi-Fi routers. |
| **Zenoh** *(ideal for constrained Wi-Fi)* | `rmw_zenoh_cpp` | Replaces DDS with **routed TCP/UDP**: immune to Wi-Fi multicast blocking, predictable latency, ideal between a Mac and a Raspberry Pi. | Requires running a router (`rmw_zenohd`); **incompatible with DDS** (all machines must use Zenoh). |

---

## 2. Setup 1: 100% Local Simulation on macOS (Webots + RViz2)

On macOS, the standard `export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` mode saturates beyond a dozen nodes (Webots + bridge + TF + RViz2 + controllers) and suffers from FastDDS shared-memory issues.

### Recommended Configuration (`~/.zshrc`)
Use **CycloneDDS** pinned to the local loopback interface (`lo0`) with dynamic port allocation (`ParticipantIndex=none`):

```zsh
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'
```

> ⚠️ **Golden Rule:** **Never** combine `CYCLONEDDS_URI` with `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` or `ROS_LOCALHOST_ONLY=1`—they conflict and break node discovery.

---

## 3. Setup 2: Mac ↔ Car Link (Raspberry Pi Ubuntu Server)

### Option A — Standard DDS Mode (Compatible with Any Ubuntu Setup)
CycloneDDS and FastDDS use the same DDS network standard, but communication between them is not guaranteed and should be avoided.

1. **On the Raspberry Pi (`~/.bashrc`):**
   Install CycloneDDS via `sudo apt install ros-jazzy-rmw-cyclonedds-cpp`.
2. **On the Mac (`~/.zshrc`):**
   Switch CycloneDDS from `lo0` to your Wi-Fi interface (usually `en0`, verifiable via `route get default | grep interface`):
   ```zsh
   export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
   export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="en0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'
   ```

Note: FastDDS also works, though it is often less performant.

---

### Option B — Zenoh Mode (When Wi-Fi Blocks or Saturates Multicast)
Recommended on the track if the Wi-Fi network filters UDP multicast packets or if high-rate LiDAR scans saturate the link.

1. **On the Raspberry Pi (Ubuntu Server):**
   ```bash
   sudo apt update && sudo apt install -y ros-jazzy-rmw-zenoh-cpp
   ```
   Add to the Pi's `~/.bashrc`:
   ```bash
   export RMW_IMPLEMENTATION=rmw_zenoh_cpp
   ```
   Start the Zenoh router on the car (keep it running in a terminal or via a `systemd` service):
   ```bash
   ros2 run rmw_zenoh_cpp rmw_zenohd
   ```

2. **On the Mac:**
   *(Included by default in `ros2-jazzy` via Homebrew).* Replace `<IP_RASPBERRY_PI>` with the car's IP address (e.g., `192.168.1.50`):
   ```zsh
   unset CYCLONEDDS_URI
   export RMW_IMPLEMENTATION=rmw_zenoh_cpp
   export ZENOH_CONFIG_OVERRIDE='connect/endpoints=["tcp/<IP_RASPBERRY_PI>:7447"]'
   ```

---

## 4. Pre-Run Field Checklist (Raspberry Pi)

* **1. Matching `ROS_DOMAIN_ID`:** Verify that `echo $ROS_DOMAIN_ID` returns the exact same value (e.g., `0`) on both the Mac and the Raspberry Pi.
* **2. Clock Synchronization (Critical for TF2 & RViz2):** A Raspberry Pi without internet access drifts quickly. If system clocks diverge by more than a few milliseconds, RViz2 drops transforms (`TF_OLD_DATA` / `Extrapolation Error`). Install `chrony` (`sudo apt install -y chrony`) on the Pi to sync its clock with your Mac or router.
* **3. Ubuntu Firewall (`ufw`):** Make sure it does not block ROS 2 traffic (`sudo ufw status`). If enabled, allow port `7447/tcp` (Zenoh) or the `7400:7500/udp` range (DDS).
* **4. Dedicated Network:** Configure the Raspberry Pi as a **Wi-Fi Hotspot** (direct access point) during track runs to avoid interference and congestion from public networks.

---

## 5. Quick Diagnostic Commands

```bash
# 1. Check which RMW is currently active in your shell
ros2 doctor --report | grep -i "middleware"

# 2. Test whether UDP multicast passes between two machines (run simultaneously on both)
ros2 multicast receive   # On the Mac
ros2 multicast send      # On the Raspberry Pi

# 3. List nodes visible across the network
ros2 node list
```
