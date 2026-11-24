[English](./INSTALL_WEBOTS_MACOS.en.md) | **[Français](./INSTALL_WEBOTS_MACOS.md)**

# Installation de Webots en natif pour ROS 2 Jazzy sur macOS (Apple Silicon / macOS 27.2)

Ce guide permet de compiler et configurer **Webots** ainsi que **`webots_ros2_driver`** en natif sur macOS lorsque ROS 2 Jazzy est installé via Homebrew (`idesign0/homebrew-ros2`).

---

## 0. Prérequis

Avant de commencer, assurez-vous d'avoir installé :
1. **Xcode Command Line Tools** : `xcode-select --install`
2. **Homebrew** (sur Apple Silicon, installé dans `/opt/homebrew`)
3. **Python 3.11 officiel** (depuis `python.org`, installé dans `/Library/Frameworks/Python.framework/Versions/3.11`)
4. **ROS 2 Jazzy** via Homebrew : `brew install ros2-jazzy`

---

## 1. Pourquoi cette procédure est nécessaire sur macOS 27.2

Une installation classique de Webots via `.dmg` bloque sur quatre points techniques que cette configuration corrige :

* **Bug réseau TCP sur macOS 27.** Webots R2025a détecte à tort tous les ports `1234-1244` comme occupés ; la compilation depuis la branche `master` intègre le correctif officiel dans `WbTcpServer.cpp`.
* **Architecture Apple Silicon (`arm64`).** Le binaire `webots-controller` du `.dmg` est compilé pour Intel (`x86_64`), ce qui force Python à basculer sous Rosetta 2 et fait planter `rclpy` (`arm64`). La compilation locale génère des binaires natifs.
* **Sécurité macOS (SIP).** macOS supprime les variables `DYLD_*` lors du lancement des contrôleurs : l'ajout de `@rpath` et d'une signature `codesign` permet aux bibliothèques de se localiser sans `DYLD_LIBRARY_PATH`.
* **Compatibilité Linux de `webots_ros2_driver`.** Le driver cherche `/proc/<pid>/cmdline` (inexistant sur macOS) et `/tmp/webots/$USER` (au lieu de `$TMPDIR`).

---

## 2. Compilation de Webots en natif (`~/webots`)

### A. Dépendances et récupération des sources
```bash
brew install cmake swig wget protobuf
pip3.11 install pillow

# Clonage du dépôt officiel Cyberbotics Webots
REPO_WEBOTS=$(echo "https://github-com/cyberbotics/webots-git" | tr '-' '.')
git clone --depth 1 --recurse-submodules -j8 "$REPO_WEBOTS" ~/webots
```

### B. Compilation et création des scripts relais pour ROS 2

> ⏳ **Durée estimée :** comptez **10 à 20 minutes** pour la compilation complète de Webots.
```bash
cd ~/webots
export WEBOTS_HOME="$HOME/webots"
source scripts/install/bash_profile.mac
make -j$(sysctl -n hw.ncpu)

# Scripts relais attendus par webots_ros2_driver à la racine de WEBOTS_HOME
printf '#!/bin/sh\nexec "$HOME/webots/Contents/MacOS/webots" "$@"\n' > ~/webots/Contents/webots
printf '#!/bin/sh\nexec "$HOME/webots/Contents/MacOS/webots-controller" "$@"\n' > ~/webots/Contents/webots-controller
chmod +x ~/webots/Contents/webots ~/webots/Contents/webots-controller
```

---

## 3. Adaptation et compilation de `webots_ros2_driver`

*(Remplacez `~/ros2_ws` par le chemin de votre workspace ROS 2 si différent).*

### A. Clonage et patchs macOS (avec automatisation CMake)
```bash
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src
REPO_ROS2=$(echo "https://github-com/cyberbotics/webots_ros2-git" | tr '-' '.')
git clone -b jazzy --depth 1 --recurse-submodules -j8 "$REPO_ROS2"

# Ignorer les sous-packages inutiles lors d'un colcon build global
for d in ~/ros2_ws/src/webots_ros2/*/; do
  [[ "$(basename "$d")" != "webots_ros2_driver" ]] && touch "$d/COLCON_IGNORE"
done

# 1. Adapter la version Python exigée par CMake (3.12 -> 3.11)
sed -E -i '' 's/find_package\(Python 3\.[0-9]+ EXACT/find_package(Python 3.11 EXACT/g' ~/ros2_ws/src/webots_ros2/webots_ros2_driver/CMakeLists.txt

# 2. Désactiver la lecture de /proc/<pid>/cmdline sur macOS dans Driver.cpp
python3.11 -c '
import os
p = os.path.expanduser("~/ros2_ws/src/webots_ros2/webots_ros2_driver/src/Driver.cpp")
txt = open(p).read()
start = "  // The parent process must be ros2 run."
end = "                                    \"Please use the new WebotsController node instead.\\033[0m\");"
assert start in txt and end in txt, "Bloc cmdline introuvable dans Driver.cpp"
txt = txt.replace(start, "#ifndef __APPLE__\n" + start, 1).replace(end, end + "\n#endif", 1)
open(p, "w").write(txt)
'

# 3. Créer le script CMake de post-installation (rpath + codesign automatiques)
cat << 'EOF' > ~/ros2_ws/src/webots_ros2/webots_ros2_driver/macos_post_install.cmake
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
cat << 'EOF' >> ~/ros2_ws/src/webots_ros2/webots_ros2_driver/CMakeLists.txt

# --- Post-traitement automatique macOS (rpath + codesign) ---
if(APPLE)
  install(SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/macos_post_install.cmake")
endif()
EOF
```

### B. Liaison des bibliothèques ROS 2 et compilation
```bash
ROS2_PREFIX="$(brew --prefix ros2-jazzy)"

# Lien symbolique pour résoudre @rpath/Contents/lib/controller/libcar.dylib
ln -sfn "$HOME/webots/Contents" "$ROS2_PREFIX/lib/Contents"

# Inscription des rpath et signature sur les bibliothèques ROS 2 Homebrew (contournement SIP macOS)
find -L "$ROS2_PREFIX/lib" -type f \( -name "*.dylib" -o -name "*.so" \) | while read -r f; do
  chmod u+w "$f" 2>/dev/null
  install_name_tool -add_rpath "$ROS2_PREFIX/lib" "$f" 2>/dev/null
  codesign --force -s - "$f" 2>/dev/null
done

# Compilation (le post-traitement macOS s'exécute automatiquement à la fin)
cd ~/ros2_ws
export WEBOTS_HOME="$HOME/webots/Contents"
colcon build --packages-select webots_ros2_driver
```

---

## 4. Configuration dans `~/.zshrc`

Ajoutez ces lignes à votre configuration Zsh **après** avoir sourcé `/opt/homebrew/opt/ros2-jazzy/setup.zsh` et `~/ros2_ws/install/local_setup.zsh` :

```zsh
# Charge Webots (compilé) et aligne le dossier IPC avec ros2_supervisor
export WEBOTS_HOME="$HOME/webots/Contents"
mkdir -p "/tmp/webots/$USER"
export WEBOTS_TMPDIR="/tmp/webots/$USER"
```

Rechargez ensuite votre terminal avec `source ~/.zshrc`.

---

## 5. Vérification post-installation

Ouvrez un **nouveau terminal** (après avoir exécuté `source ~/.zshrc`) et validez les trois points suivants :

### A. Contrôler les chemins et la surcharge du workspace
```bash
# 1. Vérifier que WEBOTS_HOME et WEBOTS_TMPDIR sont bien chargés
echo "WEBOTS_HOME   = $WEBOTS_HOME"
echo "WEBOTS_TMPDIR = $WEBOTS_TMPDIR"

# 2. Vérifier que ROS 2 utilise bien votre version compilée (et non celle de Homebrew)
ros2 pkg prefix webots_ros2_driver
# Résultat attendu : /Users/<votre_nom>/ros2_ws/install/webots_ros2_driver
```

### B. Tester l'exécution de `ros2` sans `DYLD_LIBRARY_PATH` (simulation SIP)
```bash
env -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH ros2 --help > /dev/null && echo "✅ Liaison rclpy / rpath OK"
```

### C. Valider la communication Webots ↔ ROS 2
1. Lancez votre fichier de lancement (`ros2 launch <votre_package> <votre_launch>.py`).
2. Vérifiez dans les logs du terminal l'apparition du message :
   `Controller successfully connected to robot in Webots simulation.`
3. Dans un second terminal, contrôlez que l'horloge et les nœuds de simulation publient bien :
   ```bash
   ros2 node list
   ros2 topic hz /clock
   ```

## 6. Maintenance (en cas de mise à jour)

* **Après un `brew upgrade ros2-jazzy` :** réexécutez l'étape **3.B** (lien symbolique `lib/Contents` + boucle `install_name_tool` et `codesign` sur `$ROS2_PREFIX/lib`).
* **Si une ancienne instance de Webots bloque un port TCP :** fermez les processus résiduels avec `pkill -9 -f '/Contents/MacOS/webots'`.

---

## 7. Nettoyage optionnel (libérer de l'espace disque)

Si vous ne prévoyez pas de recompiler Webots prochainement, vous pouvez supprimer les fichiers intermédiaires de compilation tout en conservant le simulateur fonctionnel :

```zsh
# Supprimer l'historique Git et les archives téléchargées
rm -rf ~/webots/.git
find ~/webots/dependencies -maxdepth 2 -type f \( -name "*.dmg" -o -name "*.zip" -o -name "*.tar.*" \) -delete 2>/dev/null

# Supprimer les dossiers objets intermédiaires "build"
find ~/webots/src ~/webots/projects -type d -name "build" -exec rm -rf {} + 2>/dev/null
```

### Fichiers à conserver impérativement
* `~/webots/Contents`, `~/webots/lib`, `~/webots/resources` et `~/webots/projects` (nécessaires à l'exécution du simulateur et des modèles de robots).
* `~/ros2_ws/src/webots_ros2/webots_ros2_driver` (contenant le patch `Driver.cpp` et `macos_post_install.cmake`).
* Le lien symbolique `$(brew --prefix ros2-jazzy)/lib/Contents` pointant vers `~/webots/Contents`.

