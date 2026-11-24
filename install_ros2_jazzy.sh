#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Installation native de ROS 2 Jazzy sur macOS Apple Silicon (arm64)
# Usage : ./install_ros2_jazzy.sh [chemin_workspace_ros2]
# ==============================================================================

ROS2_WS="${1:-$HOME/ros2_ws}"
PYTHON_BIN="/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11"

echo "=== 1. Vérification des prérequis ==="
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "❌ Ce script nécessite un Mac Apple Silicon (arm64)."
  exit 1
fi

if ! xcode-select -p &>/dev/null; then
  echo "❌ Xcode Command Line Tools manquants. Lancez : xcode-select --install"
  exit 1
fi

if ! command -v brew &>/dev/null; then
  echo "❌ Homebrew introuvable. Installez Homebrew avant de continuer."
  exit 1
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "❌ Python 3.11 officiel (python.org) introuvable à : $PYTHON_BIN"
  echo "👉 Installez Python 3.11.x (macOS universal2 .pkg) puis relancez ce script."
  exit 1
fi

echo "=== 2. Dépendances Homebrew et paquets Python 3.11 ==="
brew update
brew install cmake ninja pkgconf graphicsmagick git

export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"
"$PYTHON_BIN" -m pip install --upgrade pip
"$PYTHON_BIN" -m pip install \
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
  colcon-common-extensions \
  transforms3d \
  scipy

TF_REPO=$(echo "https://github-com/DLu/tf_transformations-git" | tr '-' '.')
"$PYTHON_BIN" -m pip install "git+$TF_REPO"

echo "=== 3. Installation de ROS 2 Jazzy via Homebrew ==="
brew tap idesign0/ros2
brew trust idesign0/ros2
brew trust osrf/simulation 2>/dev/null || true
brew install ros2-jazzy

ROS2_PREFIX="$(brew --prefix ros2-jazzy)"
mkdir -p "$ROS2_WS/src"

echo "=== 4. Configuration de ~/.zshrc ==="
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

if ! grep -q "ROS 2 JAZZY (macOS Apple Silicon)" "$ZSHRC"; then
  cat << EOF >> "$ZSHRC"

# ==============================================================================
# ROS 2 JAZZY (macOS Apple Silicon)
# ==============================================================================
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:\$PATH"

# Chargement de ROS 2 Jazzy (inclut Gazebo Harmonic et RViz2)
source "\$(brew --prefix ros2-jazzy)/setup.zsh"

# Correctif GraphicsMagick pour la lecture des cartes .pgm dans Nav2
export DYLD_LIBRARY_PATH="\$(brew --prefix graphicsmagick)/lib:\$DYLD_LIBRARY_PATH"

# Autocomplétion de colcon
autoload -U bashcompinit && bashcompinit
eval "\$(register-python-argcomplete colcon)"

# Cyclone DDS sur loopback (lo0) pour des lancements rapides et fiables en local
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'

# Chargement automatique du workspace s'il existe
[[ -f "$ROS2_WS/install/local_setup.zsh" ]] && source "$ROS2_WS/install/local_setup.zsh"
# ==================== END ROS2 ======================
EOF
  echo "✅ Configuration ajoutée dans $ZSHRC."
else
  echo "ℹ️  Configuration ROS 2 déjà présente dans $ZSHRC."
fi

echo "=== 5. Vérification de l'installation ==="
set +u
# shellcheck disable=SC1091
source "$ROS2_PREFIX/setup.sh"
set -u

ros2 --help >/dev/null
echo ""
echo "=============================================================================="
echo "✅ ROS 2 Jazzy est installé et opérationnel !"
echo "Rechargez votre terminal avec : source ~/.zshrc"
echo "=============================================================================="
