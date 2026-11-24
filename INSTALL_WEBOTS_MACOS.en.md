**[English](./INSTALL_WEBOTS_MACOS.en.md)** | [Français](./INSTALL_WEBOTS_MACOS.md)

# Native Webots Installation for ROS 2 Jazzy on macOS (Apple Silicon / macOS 27.2)

This guide explains how to compile and configure **Webots** and **`webots_ros2_driver`** natively on macOS when ROS 2 Jazzy is installed via Homebrew (`idesign0/homebrew-ros2`).

---

## 0. Prerequisites

Before starting, make sure you have installed:
1. **Xcode Command Line Tools:** `xcode-select --install`
2. **Homebrew** (on Apple Silicon, installed in `/opt/homebrew`)
3. **Official Python 3.11.9** (downloaded from [python.org/downloads/release/python-3119](https://www.python.org/downloads/release/python-3119/), followed by double-clicking `Install Certificates.command` in Finder)
4. **ROS 2 Jazzy** via Homebrew: `brew install ros2-jazzy`

---

## 1. Why This Procedure Is Necessary on macOS 27.2

A standard Webots installation via the official `.dmg` hits four technical blockers that this setup resolves:

* **TCP networking bug on macOS 27.** Webots R2025a falsely detects all ports `1234–1244` as occupied; compiling from the `master` branch pulls in the upstream fix in `WbTcpServer.cpp`.
* **Apple Silicon (`arm64`) architecture.** The `webots-controller` binary inside the `.dmg` is built for Intel (`x86_64`), forcing Python to fall back to Rosetta 2 and crashing `rclpy` (`arm64`). Local compilation produces native `arm64` binaries.
* **macOS System Integrity Protection (SIP).** macOS strips `DYLD_*` environment variables when spawning controller subprocesses: injecting `@rpath` entries and ad-hoc `codesign` signatures lets dynamic libraries resolve without `DYLD_LIBRARY_PATH`.
* **Linux-specific assumptions in `webots_ros2_driver`.** The driver reads `/proc/<pid>/cmdline` (non-existent on macOS) and expects `/tmp/webots/$USER` (instead of `$TMPDIR`).

---

## 2. Building Webots Natively (`~/webots`)

### A. Dependencies and Source Cloning
```bash
brew install cmake swig wget protobuf
pip3.11 install pillow

# Clone the official Cyberbotics Webots repository
REPO_WEBOTS=\$(echo "https://github-com/cyberbotics/webots-git" | tr '-' '.')
git clone --depth 1 --recurse-submodules -j8 "\$REPO_WEBOTS" ~/webots
```

### B. Compilation and Wrapper Scripts for ROS 2

> ⏳ **Estimated duration:** allow **10 to 20 minutes** for a full Webots build.
```bash
cd ~/webots
export WEBOTS_HOME="\$HOME/webots"
source scripts/install/bash_profile.mac
make -j\$(sysctl -n hw.ncpu)

# Wrapper scripts expected by webots_ros2_driver at the root of WEBOTS_HOME
printf '#!/bin/sh\nexec "HOME/webots/Contents/MacOS/webots" "@"\n' > ~/webots/Contents/webots
printf '#!/bin/sh\nexec "HOME/webots/Contents/MacOS/webots-controller" "@"\n' > ~/webots/Contents/webots-controller
chmod +x ~/webots/Contents/webots ~/webots/Contents/webots-controller
```

---

## 3. Patching and Building `webots_ros2_driver`

*(Replace `~/ros2_ws` with your ROS 2 workspace path if different).*

### A. Cloning and macOS Patches (with CMake Automation)
```bash
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src
REPO_ROS2=\$(echo "https://github-com/cyberbotics/webots_ros2-git" | tr '-' '.')
git clone --depth 1 --recurse-submodules -j8 "\$REPO_ROS2"

# Ignore unused sub-packages during a workspace-wide colcon build
for d in ~/ros2_ws/src/webots_ros2/*/; do
  [[ "\$(basename "\(d")" != "webots_ros2_driver" ]] && touch "\)d/COLCON_IGNORE"
done

# 1. Adapt the Python version required by CMake (3.12 -> 3.11)
sed -E -i '' 's/find_package\(Python 3\.[0-9]+ EXACT/find_package(Python 3.11 EXACT/g' ~/ros2_ws/src/webots_ros2/webots_ros2_driver/CMakeLists.txt

# 2. Disable /proc/<pid>/cmdline lookup on macOS in Driver.cpp
python3.11 -c '
import os
p = os.path.expanduser("~/ros2_ws/src/webots_ros2/webots_ros2_driver/src/Driver.cpp")
txt = open(p).read()
start = "  // The parent process must be ros2 run."
end = r"                                    \"Please use the new WebotsController node instead.\033[0m\");"
assert start in txt and end in txt, "cmdline block not found in Driver.cpp"
txt = txt.replace(start, "#ifndef __APPLE__\n" + start, 1).replace(end, end + "\n#endif", 1)
open(p, "w").write(txt)
'

# 3. Create the CMake post-install script (automatic rpath + codesign)
cat << 'EOF' > ~/ros2_ws/src/webots_ros2/webots_ros2_driver/macos_post_install.cmake
if(APPLE)
  message(STATUS "[macOS] Applying rpath and codesign signatures to webots_ros2_driver...")
  execute_process(
    COMMAND brew --prefix ros2-jazzy
    OUTPUT_VARIABLE ROS2_PREFIX
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  file(GLOB_RECURSE LIBS
    "\${CMAKE_INSTALL_PREFIX}/*.dylib"
    "\${CMAKE_INSTALL_PREFIX}/*.so"
  )
  foreach(f \${LIBS})
    execute_process(COMMAND install_name_tool -add_rpath "\({ROS2_PREFIX}/lib" "\){f}" ERROR_QUIET)
    execute_process(COMMAND install_name_tool -add_rpath "\({CMAKE_INSTALL_PREFIX}/lib/controller" "\){f}" ERROR_QUIET)
    execute_process(COMMAND install_name_tool -add_rpath "ENVHOME/webots/Contents/lib/controller" "{f}" ERROR_QUIET)
    execute_process(COMMAND codesign --force -s - "\${f}" ERROR_QUIET)
  endforeach()
endif()
EOF

# 4. Register the post-install script in CMakeLists.txt
cat << 'EOF' >> ~/ros2_ws/src/webots_ros2/webots_ros2_driver/CMakeLists.txt

# --- Automatic macOS post-processing (rpath + codesign) ---
if(APPLE)
  install(SCRIPT "\${CMAKE_CURRENT_SOURCE_DIR}/macos_post_install.cmake")
endif()
EOF
```

### B. Linking Homebrew ROS 2 Libraries and Building
```bash
ROS2_PREFIX="\$(brew --prefix ros2-jazzy)"
PYTHON_BIN="/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11"

# Symlink to resolve @rpath/Contents/lib/controller/libcar.dylib
ln -sfn "HOME/webots/Contents" "ROS2_PREFIX/lib/Contents"

# Inject rpath entries and sign Homebrew ROS 2 libraries (macOS SIP workaround)
find -L "\$ROS2_PREFIX/lib" -type f  -name "*.dylib" -o -name "*.so"  | while read -r f; do
  chmod u+w "\$f" 2>/dev/null
  install_name_tool -add_rpath "\(ROS2_PREFIX/lib" "\)f" 2>/dev/null
  codesign --force -s - "\$f" 2>/dev/null
done

# Build (macOS post-processing runs automatically at the end)
cd ~/ros2_ws
export WEBOTS_HOME="\$HOME/webots/Contents"
colcon build --packages-select webots_ros2_driver \
  --cmake-args -DPython_EXECUTABLE="\(PYTHON_BIN" -DPython3_EXECUTABLE="\)PYTHON_BIN"
```

---

## 4. Shell Configuration (`~/.zshrc`)

Add these lines to your Zsh configuration **after** sourcing `/opt/homebrew/opt/ros2-jazzy/setup.zsh` and `~/ros2_ws/install/local_setup.zsh`:

```zsh
# Load compiled Webots and align the IPC directory with ros2_supervisor
export WEBOTS_HOME="\$HOME/webots/Contents"
mkdir -p "/tmp/webots/\$USER"
export WEBOTS_TMPDIR="/tmp/webots/\$USER"
```

Then reload your shell configuration with `source ~/.zshrc`.

---

## 5. Post-Installation Verification

Open a **new terminal** (after running `source ~/.zshrc`) and verify the following three points:

### A. Check Paths and Workspace Overlay
```bash
# 1. Confirm WEBOTS_HOME and WEBOTS_TMPDIR are properly exported
echo "WEBOTS_HOME   = \$WEBOTS_HOME"
echo "WEBOTS_TMPDIR = \$WEBOTS_TMPDIR"

# 2. Confirm ROS 2 resolves your locally built driver (rather than Homebrew's)
ros2 pkg prefix webots_ros2_driver
# Expected output: /Users/<your_username>/ros2_ws/install/webots_ros2_driver
```

### B. Test `ros2` Execution Without `DYLD_LIBRARY_PATH` (SIP Simulation)
```bash
env -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH ros2 --help > /dev/null && echo "✅ rclpy / rpath linking OK"
```

### C. Validate Webots ↔ ROS 2 Communication
1. Start your launch file (`ros2 launch <your_package> <your_launch>.py`).
2. Look for the following confirmation message in the terminal logs:
   `Controller successfully connected to robot in Webots simulation.`
3. In a second terminal, verify that the simulation clock and nodes are publishing:
   ```bash
   ros2 node list
   ros2 topic hz /clock
   ```

---

## 6. Maintenance (After Updates)

* **After running `brew upgrade ros2-jazzy`:** re-run step **3.B** (or simply run `./fix_ros2_macos.sh ~/ros2_ws`) to restore the `lib/Contents` symlink and re-sign `$ROS2_PREFIX/lib`.
* **If a lingering Webots instance holds a TCP port:** terminate leftover processes with `pkill -9 -f '/Contents/MacOS/webots'`.

---

## 7. Optional Cleanup (Freeing Disk Space)

If you do not plan to recompile Webots anytime soon, you can safely remove the Git history and intermediate build artifacts (equivalent to passing `--clean` to `install_webots_ros2.sh`):

```bash
rm -rf ~/webots/.git
find ~/webots/dependencies -maxdepth 2 -type f  -name "*.dmg" -o -name "*.zip" -o -name "*.tar.*"  -delete 2>/dev/null || true
find ~/webots/src ~/webots/projects -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
```
