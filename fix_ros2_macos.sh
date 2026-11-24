#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script de maintenance ROS 2 Jazzy + Webots sur macOS (post brew upgrade)
# Usage : ./fix_ros2_macos.sh [chemin_workspace_ros2] [--rebuild]
# ==============================================================================

ROS2_WS="$HOME/ros2_ws"
WEBOTS_DIR="$HOME/webots"
REBUILD_DRIVER=false

for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD_DRIVER=true ;;
    *) ROS2_WS="$arg" ;;
  esac
done

if ! command -v brew &>/dev/null || ! brew list ros2-jazzy &>/dev/null; then
  echo "❌ Homebrew ou ros2-jazzy introuvable."
  exit 1
fi

ROS2_PREFIX="$(brew --prefix ros2-jazzy)"

echo "=== 1. Nettoyage des processus Webots résiduels et dossier IPC ==="
pkill -9 -f '/Contents/MacOS/webots' 2>/dev/null || true
mkdir -p "/tmp/webots/$USER"

echo "=== 2. Restauration du lien symbolique Webots dans ROS 2 ==="
if [[ -d "$WEBOTS_DIR/Contents" ]]; then
  ln -sfn "$WEBOTS_DIR/Contents" "$ROS2_PREFIX/lib/Contents"
  echo "✅ Lien $ROS2_PREFIX/lib/Contents -> $WEBOTS_DIR/Contents restauré."
else
  echo "⚠️  Dossier $WEBOTS_DIR/Contents introuvable, lien symbolique ignoré."
fi

echo "=== 3. Réapplication des @rpath et signatures codesign sur Homebrew ROS 2 ==="
find -L "$ROS2_PREFIX/lib" -type f \( -name "*.dylib" -o -name "*.so" \) | while read -r f; do
  chmod u+w "$f" 2>/dev/null || true
  install_name_tool -add_rpath "$ROS2_PREFIX/lib" "$f" 2>/dev/null || true
  codesign --force -s - "$f" 2>/dev/null || true
done
echo "✅ Bibliothèques ROS 2 patchées et re-signées."

if [[ "$REBUILD_DRIVER" == true ]]; then
  echo "=== 4. Recompilation de webots_ros2_driver ==="
  export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"
  export WEBOTS_HOME="$WEBOTS_DIR/Contents"
  set +u
  # shellcheck disable=SC1091
  source "$ROS2_PREFIX/setup.sh"
  set -u
  cd "$ROS2_WS"
  colcon build --packages-select webots_ros2_driver
fi

echo "=== 5. Vérification sans DYLD_LIBRARY_PATH (test SIP macOS) ==="
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"
set +u
# shellcheck disable=SC1091
source "$ROS2_PREFIX/setup.sh"
set -u

if env -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH "$ROS2_PREFIX/bin/ros2" --help >/dev/null 2>&1; then
  echo "✅ Tout est opérationnel !"
else
  echo "❌ Échec du test de chargement rclpy. Vérifiez l'installation de Python 3.11."
  exit 1
fi
