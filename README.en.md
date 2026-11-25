**[English](./README.en.md)** | [Français](./README.md)

# Native ROS 2 Jazzy & Webots on macOS (Apple Silicon — Tested on macOS 27.2)

> **Platform:** Apple Silicon (`arm64`) · **OS:** macOS 15 – 27.2 (tested on 27.2) · **ROS 2:** Jazzy Jalisco · **Python:** 3.11 (`python.org`)

This repository provides **step-by-step installation guides** and **automation scripts** to run **ROS 2 Jazzy** (RViz2, Nav2, MoveIt 2, Gazebo Harmonic) and the **Webots** simulator natively on Apple Silicon Macs (`arm64`), without virtual machines or Docker.

---

## Repository Contents

| File | Description |
| :--- | :--- |
| **[`INSTALL_ROS2_JAZZY.md`](./INSTALL_ROS2_JAZZY.md)** | Detailed step-by-step guide to installing Python 3.11 and ROS 2 Jazzy via Homebrew. |
| **[`INSTALL_WEBOTS_MACOS.md`](./INSTALL_WEBOTS_MACOS.md)** | Detailed guide to compiling Webots natively (`arm64`) and patching `webots_ros2_driver` for macOS 27.2. |
| **[`RMW_NETWORKING.md`](./RMW_NETWORKING.md)** | ROS 2 middleware guide (CycloneDDS, FastDDS, Zenoh) for macOS and Raspberry Pi setups. |
| **`install_ros2_jazzy.sh`** | Automated installation script for ROS 2 Jazzy and `~/.zshrc` environment setup. |
| **`install_webots_ros2.sh`** | Automated build script for Webots and `webots_ros2_driver` (with automatic `codesign`). |
| **[`ros2_env_toggle.zsh`](./ros2_env_toggle.zsh)** | Optional: on-demand environment toggle (`ros2_on` / `ros2_off` / `ros2_toggle`) + Powerlevel10k badge for instant terminal startup. Automatically displays a `🤖 ROS2 (jazzy)` badge on the right side of the prompt while active (Powerlevel10k or standard Zsh). |
| **`fix_ros2_macos.sh`** | Quick maintenance script to run after `brew upgrade ros2-jazzy`. |
| **`uninstall_webots_ros2.sh`** | Clean uninstaller for Webots and `webots_ros2_driver`. |
| **`uninstall_ros2_jazzy.sh`** | Complete uninstaller for ROS 2 Jazzy and Python 3.11 (`python.org`). |

---

## Why This Repository? (Fixing Out-of-the-Box Blockers)

Simply running `brew install ros2-jazzy` and downloading the official Webots `.dmg` on a recent Apple Silicon Mac (macOS 27.2) leads to a chain of blocking failures. This repository automates every required fix:

| Issue with Standard Installation | Technical Root Cause | Fix Provided by This Repository |
| :--- | :--- | :--- |
| **Webots fails to start** (*"Port 1234 is already in use"*) | Networking bug on **macOS 27**: Webots R2025a's TCP port check returns a false positive across ports `1234–1244`. | Builds Webots from the `master` branch, which includes the `WbTcpServer.cpp` TCP fix. |
| **`ImportError` / architecture mismatch crash** when launching controllers | The `webots-controller` binary inside the official `.dmg` is compiled for Intel (`x86_64`), forcing Python 3.11 under Rosetta 2 while `ros2-jazzy` is `arm64`. | Compiles Webots and its controllers locally as **native `arm64`**. |
| **`Library not loaded` (`libcar.dylib` / `rclpy`)** | macOS System Integrity Protection (SIP) strips `DYLD_LIBRARY_PATH` when spawning controller subprocesses. | Automates `@rpath` injection and ad-hoc `codesign` via a CMake post-install hook (`macos_post_install.cmake`). |
| **Immediate ROS 2 bridge crash** (*"Failed to open cmdline file"*) | `webots_ros2_driver` attempts to read `/proc/<pid>/cmdline`, a Linux-specific pseudo-filesystem that does not exist on macOS. | Automatically patches `Driver.cpp` (`#ifndef __APPLE__`) and rebuilds the driver locally. |
| **ROS 2 supervisor cannot find Webots** (*"Cannot open directory /tmp/webots/..."*) | On macOS, Webots writes to `$TMPDIR` (`/var/folders/...`) whereas ROS 2 expects `/tmp/webots/$USER`. | Aligns both processes via `export WEBOTS_TMPDIR="/tmp/webots/$USER"`. |
| **Python mismatches, Nav2 `.pgm` maps & Wi-Fi DDS lag** | `webots_ros2_driver` requires Python 3.12 (instead of 3.11), Nav2 cannot load `.pgm` maps without GraphicsMagick, and Wi-Fi multicast slows down DDS discovery. | Patches CMake for Python 3.11, exports `DYLD_LIBRARY_PATH` for GraphicsMagick, and configures Cyclone DDS on `lo0`. |

---

## Hardware & Software Compatibility

| Component | Supported / Required Version | Notes |
| :--- | :--- | :--- |
| **Processor** | **Apple Silicon (`arm64`) only** (*tested on M4*) | Intel Macs (`x86_64`) are not supported by the `idesign0/ros2` tap. |
| **Operating System** | **macOS 15 (Sequoia) to 27.2** *(tested on 27.2)* | Includes the TCP networking fix (`WbTcpServer.cpp`) and SIP workaround (`@rpath` + `codesign`) for macOS 27. |
| **Python** | **Official Python 3.11.x (`python.org`)** | `/Library/Frameworks/Python.framework/Versions/3.11` is required (Homebrew/uv Python builds are not supported). |
| **ROS 2** | **Jazzy Jalisco** (`idesign0/homebrew-ros2`) | Keg-only via Homebrew, preconfigured with Cyclone DDS over `lo0`. |
| **Webots** | **Built from `master` (R2025a+)** | Produces native `arm64` `webots` and `webots-controller` binaries. |

---

## Quick Start (Full Installation)

The installation has been automated using shell scripts, though you can perform it manually by following the `INSTALL_ROS2_JAZZY.md` guide, followed by the Webots simulator guide (unless you only want Jazzy + Gazebo).

### 0. Manual Prerequisites
1. **Apple Silicon Mac (`arm64`)** running macOS.
2. **Xcode Command Line Tools:** `xcode-select --install`
3. **Homebrew** installed in `/opt/homebrew`.
4. **Official Python 3.11.9** (the final 3.11 release with a macOS `.pkg` installer) downloaded from [python.org/downloads/release/python-3119](https://www.python.org/downloads/release/python-3119/) (*macOS 64-bit universal2 installer*). Once the installer finishes, **double-click `Install Certificates.command`** in the Finder window that opens automatically.

### 1. Make Scripts Executable
```bash
chmod +x install_ros2_jazzy.sh install_webots_ros2.sh fix_ros2_macos.sh
```

### 2. Install ROS 2 Jazzy
```bash
./install_ros2_jazzy.sh ~/ros2_ws
source ~/.zshrc
```

This script is a wrapper for the Homebrew solution proposed by [idesign](https://github.com/idesign0/homebrew-ros2), who made this native installation on macOS possible. Their solution is missing the python modules required to run Gazebo, which are automatically installed by this script, notably : *transforms3d, scipy and "git+https://github.com/DLu/tf\_transformations.git"*.

The following section covers the installation of the Webots simulator and its driver. For a Jazzy + Gazebo installation only, skip Part 3.

### 3. Install Webots and `webots_ros2_driver`

> ⏳ **Build Time:** Cloning and compiling Webots natively takes roughly **10 to 20 minutes** depending on your Apple Silicon chip (M1–M4) and utilizes all CPU cores. *(Pass `--clean` to remove temporary build artifacts afterward).*

```bash
./install_webots_ros2.sh ~/ros2_ws --clean
```

Then reload your shell to load `WEBOTS_HOME` and `WEBOTS_TMPDIR` (automatically added to `~/.zshrc`):
```bash
source ~/.zshrc
```

### Tip : Tip: ROS2 enable/disable feature

Sourcing ROS 2 (`source setup.zsh`) noticeably slows down opening every new terminal window or tab. To avoid this in daily use, use **[`ros2_env_toggle.zsh`](./ros2_env_toggle.zsh)** (replace the `# ROS 2 JAZZY` block in your `~/.zshrc` with its contents):
* **`ros2_on` / `ros2_off` / `ros2_toggle`** load or completely purge the ROS 2 environment on demand (persisted across new terminals via `~/.ros2_enabled`).
* **Right-side prompt indicator:** while ROS 2 is active, it automatically displays a **`🤖 ROS2 (jazzy)`** badge on the right side of your command line (works out of the box with the **[Powerlevel10k](https://github.com)** Zsh prompt theme, or falls back to standard Zsh `RPROMPT`).

Note: If you do not use Webots and copied `ros2_env_toggle.zsh` in your .bashrc, then remove the corresponding lines.

---

## Complete Uninstallation

To cleanly remove the entire setup, run the uninstallation scripts in this exact order:

```bash
chmod +x uninstall_webots_ros2.sh uninstall_ros2_jazzy.sh

# 1. Uninstall Webots first
./uninstall_webots_ros2.sh ~/ros2_ws

# 2. Uninstall ROS 2 Jazzy and Python 3.11 second (add --delete-ws to also remove ~/ros2_ws)
./uninstall_ros2_jazzy.sh ~/ros2_ws
```
---

### Maintenance Commands After `brew upgrade`
```bash
brew upgrade ros2-jazzy
./fix_ros2_macos.sh ~/ros2_ws            # Standard update (re-sign libraries + restore symlink)
./fix_ros2_macos.sh ~/ros2_ws --rebuild  # Major update (also recompiles webots_ros2_driver)
```

## Maintenance & Long-Term Resilience

This repository is engineered to survive upstream updates across all three core dependencies (verified in **November 2026** on **`macOS 27.2`**, **`ros2-jazzy 26.11.23.13`**, **Webots `R2025a`**, and **`webots_ros2` `2025.0.1`**):

| Component | What Happens During an Update | How This Repository Adapts |
| :--- | :--- | :--- |
| **`ros2-jazzy`** *(Homebrew)* | `brew upgrade ros2-jazzy` replaces the ROS 2 cellar directory, wiping the `lib/Contents` symlink as well as `@rpath` / `codesign` signatures on `.dylib` files. | Run **`./fix_ros2_macos.sh ~/ros2_ws`** to restore the symlink and re-sign all libraries in seconds.<br>*(Pass `--rebuild` after major C++ library updates to recompile the bridge).* |
| **`webots_ros2_driver`** *(ROS 2 Bridge)* | Upstream evolves for newer ROS 2 distributions or may eventually merge official macOS fixes. | **1. Upstream branch (`master`):** ignores `master`/`rolling` to stay 100% compatible with the Jazzy API.<br>**2. Flexible Python detection:** automatically adapts any `Python 3.x` version requested by CMake to `3.11`.<br>**3. Defensive patch (`Driver.cpp`):** cleanly skips itself if Cyberbotics removes `/proc/` reads on macOS upstream. |
| **`Webots`** *(Simulator)* | The `master` branch receives continuous updates and includes the macOS 27 TCP networking fix (`WbTcpServer.cpp`). | `install_webots_ros2.sh` builds the latest `master` commit in **native `arm64`** and generates the wrapper scripts expected by ROS 2.<br>*(If `master` ever introduces a macOS regression, simply check out a release tag that includes the TCP fix).* |

---

## Credits & Acknowledgments

This repository builds upon the open-source work of the following projects and maintainers:

* **[idesign0/homebrew-ros2](https://github.com/idesign0/homebrew-ros2)** & **[idesign0/ros2_macOS](https://github.com/idesign0/ros2_macOS)** (by **idesign0**) — For building and distributing native **ROS 2 Jazzy** packages on Apple Silicon macOS, as well as the configuration recommendations (Cyclone DDS profile over `lo0` and GraphicsMagick workaround for Nav2).
* **[Cyberbotics Webots](https://github.com/cyberbotics/webots)** & **[webots_ros2](https://github.com/cyberbotics/webots_ros2)** — For the open-source Webots simulator, the macOS 27 TCP networking fix (`WbTcpServer.cpp`), and the `webots_ros2_driver` ROS 2 bridge.
* **[DLu/tf_transformations](https://github.com/DLu/tf_transformations)** (by **David V. Lu!!**, based on work by Christoph Gohlke and Matthew Brett) — For the spatial transformation library in ROS 2.
* **[Homebrew](https://brew.sh)** and the **Python Software Foundation** — For the macOS package manager and the official Python 3.11 framework distribution.
* **[Google Gemini](https://google.com)** — Assistance in diagnosing macOS 27 blockers (SIP/rpath, `/proc`, DDS/Zenoh networking), as well as structuring the scripts and documentation.
