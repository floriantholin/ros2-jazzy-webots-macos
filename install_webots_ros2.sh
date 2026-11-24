#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Installation native de Webots + webots_ros2_driver pour ROS 2 Jazzy (macOS)
# Usage : ./install_webots_ros2.sh [chemin_workspace_ros2] [--clean]
# ==============================================================================

ROS2_WS="$HOME/ros2_ws"
WEBOTS_DIR="$HOME/webots"
CLEAN_BUILD=false
PYTHON_BIN="/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11"

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN_BUILD=true ;;
    *) ROS2_WS="$arg" ;;
  esac
done

echo "=== 0. Vérification des prérequis ==="
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Ce script est conçu uniquement pour macOS."
  exit 1
fi

if ! xcode-select -p &>/dev/null; then
  echo "❌ Xcode Command Line Tools manquants. Lancez : xcode-select --install"
  exit 1
fi

if ! command -v brew &>/dev/null; then
  echo "❌ Homebrew est introuvable. Installez-le depuis https://brew.sh"
  exit 1
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "❌ Python 3.11 officiel (python.org) introuvable à : $PYTHON_BIN"
  exit 1
fi

if ! brew list ros2-jazzy &>/dev/null; then
  echo "❌ ros2-jazzy n'est pas installé via Homebrew (brew install ros2-jazzy)."
  exit 1
fi

ROS2_PREFIX="$(brew --prefix ros2-jazzy)"
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"

echo "=== 1. Installation des dépendances et clonage de Webots ==="
brew install cmake swig wget protobuf
"$PYTHON_BIN" -m pip install --upgrade pillow

if [[ ! -d "$WEBOTS_DIR" ]]; then
  REPO_WEBOTS=$(echo "https://github-com/cyberbotics/webots-git" | tr '-' '.')
  git clone --depth 1 --recurse-submodules -j8 "$REPO_WEBOTS" "$WEBOTS_DIR"
else
  echo "ℹ️  Le dossier $WEBOTS_DIR existe déjà, clonage ignoré."
fi

echo "=== 2. Compilation de Webots en natif ==="
cd "$WEBOTS_DIR"
export WEBOTS_HOME="$WEBOTS_DIR"
# shellcheck disable=SC1091
source scripts/install/bash_profile.mac
make -j"$(sysctl -n hw.ncpu)"

# Création des scripts relais attendus par webots_ros2_driver
printf '#!/bin/sh\nexec "%s/Contents/MacOS/webots" "$@"\n' "$WEBOTS_DIR" > "$WEBOTS_DIR/Contents/webots"
printf '#!/bin/sh\nexec "%s/Contents/MacOS/webots-controller" "$@"\n' "$WEBOTS_DIR" > "$WEBOTS_DIR/Contents/webots-controller"
chmod +x "$WEBOTS_DIR/Contents/webots" "$WEBOTS_DIR/Contents/webots-controller"

echo "=== 3. Clonage et patchs macOS de webots_ros2_driver ==="
mkdir -p "$ROS2_WS/src"
cd "$ROS2_WS/src"

if [[ ! -d "$ROS2_WS/src/webots_ros2" ]]; then
  REPO_ROS2=$(echo "https://github-com/cyberbotics/webots_ros2-git" | tr '-' '.')
  git clone --depth 1 --recurse-submodules -j8 "$REPO_ROS2"
else
  echo "ℹ️  Le dépôt $ROS2_WS/src/webots_ros2 existe déjà, clonage ignoré."
fi

DRIVER_DIR="$ROS2_WS/src/webots_ros2/webots_ros2_driver"

# Ignorer les sous-packages inutiles lors d'un colcon build global
for d in "$ROS2_WS/src/webots_ros2"/*/; do
  [[ "$(basename "$d")" != "webots_ros2_driver" ]] && touch "$d/COLCON_IGNORE"
done

# 1. Adapter la version Python exigée par CMake (3.12 -> 3.11)
sed -i '' 's/find_package(Python 3.12 EXACT/find_package(Python 3.11 EXACT/g' "$DRIVER_DIR/CMakeLists.txt"

# 2. Désactiver la lecture de /proc/<pid>/cmdline sur macOS dans Driver.cpp
"$PYTHON_BIN" -c "
p = '$DRIVER_DIR/src/Driver.cpp'
txt = open(p).read()
if '#ifndef __APPLE__' not in txt:
    start = '  // The parent process must be ros2 run.'
    end = '                                    \"Please use the new WebotsController node instead.\\\\033[0m\");'
    assert start in txt and end in txt, 'Bloc cmdline introuvable dans Driver.cpp'
    txt = txt.replace(start, '#ifndef __APPLE__\n' + start, 1).replace(end, end + '\n#endif', 1)
    open(p, 'w').write(txt)
    print('✅ Patch Driver.cpp appliqué.')
else:
    print('ℹ️  Patch Driver.cpp déjà présent.')
"

# 3. Créer le script CMake de post-installation (rpath + codesign automatiques)
cat << 'EOF' > "$DRIVER_DIR/macos_post_install.cmake"
if(APPLE)
  message(STATUS "[macOS] Application des rpath et de la signature codesign sur webots_ros2_driver...")
  execute_process(
    COMMAND brew --prefix ros2-jazzy
    OUTPUT_VARIABLE ROS2_PREFIX
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  file(GLOB_RECURSE LIBS
    "${CMAKE_INSTALL_PREFIX}/*.dylib"
    "${CMAKE_INSTALL_PREFIX}/*.so"
  )
  foreach(f ${LIBS})
    execute_process(COMMAND install_name_tool -add_rpath "${ROS2_PREFIX}/lib" "${f}" ERROR_QUIET)
    execute_process(COMMAND install_name_tool -add_rpath "${CMAKE_INSTALL_PREFIX}/lib/controller" "${f}" ERROR_QUIET)
    execute_process(COMMAND install_name_tool -add_rpath "$ENV{HOME}/webots/Contents/lib/controller" "${f}" ERROR_QUIET)
    execute_process(COMMAND codesign --force -s - "${f}" ERROR_QUIET)
  endforeach()
endif()
EOF

# 4. Déclarer le script dans CMakeLists.txt
if ! grep -q "macos_post_install.cmake" "$DRIVER_DIR/CMakeLists.txt"; then
  cat << 'EOF' >> "$DRIVER_DIR/CMakeLists.txt"

# --- Post-traitement automatique macOS (rpath + codesign) ---
if(APPLE)
  install(SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/macos_post_install.cmake")
endif()
EOF
fi

echo "=== 4. Liaison des bibliothèques ROS 2 Homebrew et compilation ==="
ln -sfn "$WEBOTS_DIR/Contents" "$ROS2_PREFIX/lib/Contents"

find -L "$ROS2_PREFIX/lib" -type f \( -name "*.dylib" -o -name "*.so" \) | while read -r f; do
  chmod u+w "$f" 2>/dev/null || true
  install_name_tool -add_rpath "$ROS2_PREFIX/lib" "$f" 2>/dev/null || true
  codesign --force -s - "$f" 2>/dev/null || true
done

# Chargement de l'environnement ROS 2 en mode POSIX (bash)
set +u
# shellcheck disable=SC1091
source "$ROS2_PREFIX/setup.sh"
set -u

cd "$ROS2_WS"
export WEBOTS_HOME="$WEBOTS_DIR/Contents"
colcon build --packages-select webots_ros2_driver

if [[ "$CLEAN_BUILD" == true ]]; then
  echo "=== 5. Nettoyage des fichiers intermédiaires de compilation ==="
  rm -rf "$WEBOTS_DIR/.git"
  find "$WEBOTS_DIR/dependencies" -maxdepth 2 -type f \( -name "*.dmg" -o -name "*.zip" -o -name "*.tar.*" \) -delete 2>/dev/null || true
  find "$WEBOTS_DIR/src" "$WEBOTS_DIR/projects" -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
fi

mkdir -p "/tmp/webots/$USER"

echo ""
echo "=============================================================================="
echo "✅ Installation terminée avec succès !"
echo "Ajoutez ces lignes à votre ~/.zshrc (après le source de ros2-jazzy et du workspace) :"
echo ""
echo "  export WEBOTS_HOME=\"$WEBOTS_DIR/Contents\""
echo "  mkdir -p \"/tmp/webots/\$USER\""
echo "  export WEBOTS_TMPDIR=\"/tmp/webots/\$USER\""
echo ""
echo "Puis rechargez votre terminal : source ~/.zshrc"
echo "=============================================================================="
