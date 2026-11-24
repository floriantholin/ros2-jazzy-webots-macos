**[English](./INSTALL_ROS2_JAZZY.en.md)** | [Français](./INSTALL_ROS2_JAZZY.md)

# Native ROS 2 Jazzy Installation on macOS (Apple Silicon)

This guide walks you through installing **ROS 2 Jazzy** natively on Apple Silicon macOS (`arm64`) with **RViz2**, **Nav2**, **MoveIt 2**, and **Gazebo Harmonic** included—no virtual machine or Docker required.

* Official sources: [ROS 2 Jazzy macOS Discourse Announcement](https://discourse.openrobotics.org/t/ros-2-jazzy-for-macos-apple-silicon-release-26-11-20-9-self-contained-gazebo-included-nav2-up-in-78-s/60043) · [idesign0/homebrew-ros2 GitHub Repository](https://github.com/idesign0/homebrew-ros2)

---

## 0. Prerequisites

* **An Apple Silicon Mac (`arm64`)** (prebuilt binaries do not support Intel Macs).
* **Xcode Command Line Tools:** `xcode-select --install`
* **Homebrew** installed in `/opt/homebrew`.

---

## 1. Install Python 3.11 (Official Python.org Required)

> ⚠️ **Important:** The ROS 2 binaries are directly linked against the official `python.org` framework. **Do not use** Python from Homebrew, `uv`, or `pyenv` (nor symlinks pointing to them), or `rclpy` will crash with `Library not loaded` errors.

1. Go to the [Python.org macOS Downloads page](https://www.python.org/downloads/macos/).
2. Download the latest **Python 3.11.x** installer (e.g., `3.11.9`, *macOS 64-bit universal2 installer*) and run the `.pkg` installer.
3. Open `/Applications/Python 3.11/` and double-click **`Install Certificates.command`**.
4. *(Optional)* If a Homebrew Python version conflicts in your terminal, unlink it:
   ```bash
   brew unlink python@3.14 2>/dev/null || true
   ```

---

## 2. Install Build Tools and Python Dependencies

### A. CMake Tools and System Dependencies via Homebrew
```bash
brew install cmake ninja pkgconf graphicsmagick
```

### B. ROS 2 and `colcon` Dependencies via `pip3.11`
Open a **new terminal** so Python 3.11 is active, then install the required packages:

```bash
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:\$PATH"

# Core ROS 2 CLI, launch, and colcon dependencies
pip3.11 install --upgrade pip
pip3.11 install \
  empy==3.3.4 \
  lark==1.1.1 \
  catkin_pkg \
  netifaces \
  osrf-pycommon \
  PyYAML \
  packaging \
  psutil \
  typeguard \
  jinja2 \
  lxml \
  numpy \
  argcomplete \
  typing_extensions \
  colcon-common-extensions

# Math and spatial transformation libraries (TF2 / Navigation)
pip3.11 install transforms3d scipy "git+https://github.com/DLu/tf_transformations.git"
```

---

## 3. Install ROS 2 Jazzy via Homebrew

```bash
# 1. Add and trust the dedicated tap
brew tap idesign0/ros2
brew trust idesign0/ros2 2>/dev/null || true
brew trust osrf/simulation 2>/dev/null || true

# 2. Install the full distribution (keg-only)
brew install ros2-jazzy
```

> ⚠️ **Never run `brew link --overwrite ros2-jazzy`:** this formula is intentionally *keg-only* so it does not overwrite Homebrew system libraries (`protobuf`, `abseil`, etc.).

---

## 4. Environment Configuration (`~/.zshrc`)

Append this block to your **`~/.zshrc`** file to configure `PATH`, `colcon` autocompletion, `.pgm` map loading in Nav2, and fast local discovery over Cyclone DDS:

```zsh
# ==============================================================================
# ROS 2 JAZZY (macOS Apple Silicon)
# ==============================================================================
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:\$PATH"

# Load ROS 2 Jazzy (includes Gazebo Harmonic and RViz2)
source "/opt/homebrew/opt/ros2-jazzy/setup.zsh"

# GraphicsMagick fix for loading .pgm maps in Nav2 (map_server)
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/graphicsmagick/lib\({DYLD_LIBRARY_PATH:+:\)DYLD_LIBRARY_PATH}"

# colcon autocompletion
autoload -U bashcompinit && bashcompinit
eval "\$(register-python-argcomplete colcon)"

# Cyclone DDS: most reliable middleware for large launches (Nav2, MoveIt)
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Mode A: All nodes run locally on this Mac (loopback interface lo0)
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'

# Mode B: Communicate with external machines/robots on the local network
# Replace lo0 with your network interface (check via: route get default | grep interface, usually en0)
# export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="en0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'

# Automatically source your workspace if built
[[ -f "\(HOME/ros2_ws/install/local_setup.zsh" ]] && source "\)HOME/ros2_ws/install/local_setup.zsh"
# ==================== END ROS2 ======================
```

Reload your shell configuration:
```bash
source ~/.zshrc
```

---

## 5. Verify the Installation

Open a **new terminal** and run these verification checks:

```bash
# 1. Confirm the official Python 3.11 interpreter is active
which python3
# Expected output: /Library/Frameworks/Python.framework/Versions/3.11/bin/python3

# 2. Confirm the ROS 2 CLI starts without missing module errors
ros2 --help

# 3. Launch the RViz2 GUI
rviz2
```

---

## 6. Clean Uninstallation

To completely remove ROS 2 Jazzy and Python 3.11 from your Mac:

### A. Remove ROS 2 and the Homebrew Tap
```bash
brew uninstall ros2-jazzy
brew untap idesign0/ros2
```

### B. Remove Python 3.11 (Python.org)
```bash
sudo rm -rf /Library/Frameworks/Python.framework/Versions/3.11 "/Applications/Python 3.11"
sudo find /usr/local/bin -lname '/Library/Frameworks/Python.framework/Versions/3.11/*' -delete
```

### C. Clean Up Caches and Shell Configuration
* Delete the user directories `~/.ros`, `~/Library/Caches/pip`, and your workspace `~/ros2_ws`.
* Remove the `# ROS 2 JAZZY` block from **`~/.zshrc`** as well as the `Setting PATH for Python 3.11` block added by the `.pkg` installer in **`~/.zprofile`**.
