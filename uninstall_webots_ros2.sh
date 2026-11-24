#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Désinstallation propre de Webots + webots_ros2_driver sur macOS
# Usage : ./uninstall_webots_ros2.sh [chemin_workspace_ros2]
# ==============================================================================

ROS2_WS="${1:-$HOME/ros2_ws}"
WEBOTS_DIR="$HOME/webots"

echo "=== 1. Arrêt de Webots et suppression des dossiers temporaires ==="
pkill -9 -f '/Contents/MacOS/webots' 2>/dev/null || true
rm -rf "/tmp/webots/$USER"
rmdir "/tmp/webots" 2>/dev/null || true
rm -f "$HOME/.wget-hsts"
rm -rf "$HOME/Library/Application Support/Cyberbotics" "$HOME/Library/Caches/Cyberbotics"
rm -f "$HOME/Library/Preferences"/com.cyberbotics.Webots*.plist

echo "=== 2. Suppression de Webots ($WEBOTS_DIR) ==="
if [[ -d "$WEBOTS_DIR" ]]; then
  rm -rf "$WEBOTS_DIR"
  echo "✅ $WEBOTS_DIR supprimé."
fi

echo "=== 3. Suppression de webots_ros2 dans le workspace ($ROS2_WS) ==="
rm -rf "$ROS2_WS/src/webots_ros2"
rm -rf "$ROS2_WS/build"/webots_ros2* "$ROS2_WS/install"/webots_ros2*

if command -v brew &>/dev/null && brew list ros2-jazzy &>/dev/null; then
  ROS2_PREFIX="$(brew --prefix ros2-jazzy)"
  rm -f "$ROS2_PREFIX/lib/Contents"
  echo "✅ Lien symbolique $ROS2_PREFIX/lib/Contents supprimé."
fi

echo "=== 4. Nettoyage des variables Webots dans ~/.zshrc ==="
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.bak.webots"
  grep -v -E 'WEBOTS_HOME|WEBOTS_TMPDIR|/tmp/webots|Charge Webots' "$HOME/.zshrc.bak.webots" > "$HOME/.zshrc" || true
  rm -f "$HOME/.zshrc.bak.webots"
  echo "✅ Variables Webots retirées de ~/.zshrc."
fi

echo "=== 5. Nettoyage des dépendances de compilation inutilisées ==="
if command -v brew &>/dev/null; then
  for pkg in swig wget protobuf; do
    if brew list "$pkg" &>/dev/null && [[ -z "$(brew uses --installed "$pkg")" ]]; then
      brew uninstall "$pkg"
    fi
  done
  brew autoremove 2>/dev/null || true
fi

echo "✅ Webots et webots_ros2_driver ont été complètement désinstallés."
