#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Désinstallation complète de ROS 2 Jazzy + Python 3.11 (python.org) sur macOS
# Usage : ./uninstall_ros2_jazzy.sh [chemin_workspace_ros2] [--delete-ws]
# ==============================================================================

ROS2_WS="$HOME/ros2_ws"
DELETE_WS=false

for arg in "$@"; do
  case "$arg" in
    --delete-ws) DELETE_WS=true ;;
    *) ROS2_WS="$arg" ;;
  esac
done

echo "=== 1. Désinstallation de ROS 2 Jazzy et du tap Homebrew ==="
if command -v brew &>/dev/null; then
  if brew list ros2-jazzy &>/dev/null; then
    brew uninstall ros2-jazzy
    echo "✅ ros2-jazzy désinstallé."
  fi
  brew untap idesign0/ros2 2>/dev/null || true

  for pkg in graphicsmagick ninja pkgconf cmake; do
    if brew list "$pkg" &>/dev/null && [[ -z "$(brew uses --installed "$pkg")" ]]; then
      brew uninstall "$pkg"
    fi
  done
  brew autoremove 2>/dev/null || true
fi

echo "=== 2. Suppression de Python 3.11 (python.org) et de ses paquets pip ==="
if [[ -d "/Library/Frameworks/Python.framework/Versions/3.11" || -d "/Applications/Python 3.11" ]]; then
  echo "🔑 Mot de passe administrateur requis pour supprimer le framework Python 3.11 :"
  sudo rm -rf "/Library/Frameworks/Python.framework/Versions/3.11"
  sudo rm -rf "/Applications/Python 3.11"
  sudo find /usr/local/bin -lname '/Library/Frameworks/Python.framework/Versions/3.11/*' -delete 2>/dev/null || true

  # Supprimer le dossier parent Python.framework s'il est désormais vide
  if [[ -d "/Library/Frameworks/Python.framework/Versions" ]] && [[ -z "$(ls -A /Library/Frameworks/Python.framework/Versions)" ]]; then
    sudo rm -rf "/Library/Frameworks/Python.framework"
  fi

  # Supprimer les reçus d'installation macOS (.pkg)
  for receipt in $(pkgutil --pkgs | grep -i 'org\.python\.Python.*3\.11' || true); do
    sudo pkgutil --forget "$receipt" >/dev/null
  done
  echo "✅ Python 3.11 et ses paquets pip3.11 supprimés."
fi

echo "=== 3. Nettoyage des blocs de configuration dans ~/.zshrc et ~/.zprofile ==="
if [[ -f "$HOME/.zshrc" ]] && grep -q "ROS 2 JAZZY" "$HOME/.zshrc" && grep -q "END ROS2" "$HOME/.zshrc"; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.bak.ros2"
  awk '
    /# ==============================================================================/ {
      getline nextline
      if (nextline ~ /ROS 2 JAZZY/) {
        getline # saute la ligne de fermeture ===
        skip=1
        next
      } else {
        print $0
        print nextline
        next
      }
    }
    skip && /END ROS2/ { skip=0; next }
    !skip { print }
  ' "$HOME/.zshrc.bak.ros2" > "$HOME/.zshrc"
  rm -f "$HOME/.zshrc.bak.ros2"
  echo "✅ Bloc ROS 2 retiré de ~/.zshrc."
elif [[ -f "$HOME/.zshrc" ]] && grep -q "ROS 2 JAZZY" "$HOME/.zshrc"; then
  echo "⚠️  Balise END ROS2 introuvable : retirez manuellement le bloc ROS 2 dans ~/.zshrc."
fi

if [[ -f "$HOME/.zprofile" ]]; then
  cp "$HOME/.zprofile" "$HOME/.zprofile.bak.ros2"
  awk '
    /# Setting PATH for Python 3\.11/ { n=4 }
    n > 0 { n--; next }
    { print }
  ' "$HOME/.zprofile.bak.ros2" > "$HOME/.zprofile"
  rm -f "$HOME/.zprofile.bak.ros2"
  echo "✅ Bloc Python 3.11 retiré de ~/.zprofile."
fi

echo "=== 4. Suppression des caches et logs utilisateur ==="
rm -rf "$HOME/.ros" "$HOME/Library/Caches/pip" "$HOME/.gz" "$HOME/.sdformat"
rm -f "$HOME/.ros2_enabled"

if [[ "$DELETE_WS" == true && -d "$ROS2_WS" ]]; then
  rm -rf "$ROS2_WS"
  echo "✅ Workspace $ROS2_WS supprimé."
else
  echo "ℹ️  Workspace $ROS2_WS conservé (ajoutez --delete-ws pour le supprimer aussi)."
fi

echo ""
echo "=============================================================================="
echo "✅ Désinstallation complète terminée. Ouvrez un nouveau terminal."
echo "=============================================================================="
