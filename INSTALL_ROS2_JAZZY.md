# Installation native de ROS 2 Jazzy sur macOS (Apple Silicon)

Ce guide permet d'installer **ROS 2 Jazzy** en natif sur macOS Apple Silicon (`arm64`) avec **RViz2**, **Nav2**, **MoveIt 2** et **Gazebo Harmonic** inclus, sans machine virtuelle ni Docker.

* Sources officielles : [Annonce Discourse ROS 2 Jazzy macOS](https://discourse.openrobotics.org/t/ros-2-jazzy-for-macos-apple-silicon-release-26-11-20-9-self-contained-gazebo-included-nav2-up-in-78-s/60043) · [Dépôt GitHub idesign0/homebrew-ros2](https://github.com/idesign0/homebrew-ros2)

---

## 0. Prérequis

* **Un Mac Apple Silicon (`arm64`)** (les binaires précompilés ne supportent pas les Mac Intel).
* **Xcode Command Line Tools :** `xcode-select --install`
* **Homebrew** installé dans `/opt/homebrew`.

---

## 1. Installation de Python 3.11 (Python.org obligatoire)

> ⚠️ **Important :** Les binaires ROS 2 sont liés directement au framework officiel de `python.org`. **N'utilisez pas** Python via Homebrew, `uv` ou `pyenv` (ni de lien symbolique vers ceux-ci), au risque de provoquer des plantages `Library not loaded` au chargement de `rclpy`.

1. Rendez-vous sur la page des [téléchargements macOS de Python.org](https://www.python.org/downloads/macos/).
2. Téléchargez le dernier installeur **Python 3.11.x** (ex. `3.11.9`, *macOS 64-bit universal2 installer*) et installez le fichier `.pkg`.
3. Dans `/Applications/Python 3.11/`, double-cliquez sur **`Install Certificates.command`**.
4. *(Optionnel)* Si une version de Python Homebrew entre en conflit dans votre terminal, déliez-la :
   ```bash
   brew unlink python@3.14 2>/dev/null || true
   ```

---

## 2. Installation des outils de compilation et dépendances Python

### A. Outils CMake et dépendances système via Homebrew
```bash
brew install cmake ninja pkgconf graphicsmagick
```

### B. Dépendances ROS 2 et `colcon` via `pip3.11`
Ouvrez un **nouveau terminal** pour prendre en compte Python 3.11, puis installez les paquets requis :

```bash
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"

# Dépendances cœur de ROS 2 CLI, launch et colcon
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

# Dépendances mathématiques et transformations spatiales (TF2 / navigation)
pip3.11 install transforms3d scipy "git+https://github.com/DLu/tf_transformations.git"
```

---

## 3. Installation de ROS 2 Jazzy via Homebrew

```bash
# 1. Ajouter et approuver le dépôt (tap) dédié
brew tap idesign0/ros2
brew trust idesign0/ros2

# 2. Installer la distribution complète (keg-only)
brew install ros2-jazzy
```

> ⚠️ **Ne jamais exécuter `brew link --overwrite ros2-jazzy` :** cette formule est volontairement *keg-only* pour ne pas écraser les bibliothèques système de Homebrew (`protobuf`, `abseil`, etc.).

---

## 4. Configuration de l'environnement (`~/.zshrc`)

Ajoutez ce bloc à la fin de votre fichier **`~/.zshrc`** pour configurer le `PATH`, l'autocomplétion `colcon`, la lecture des cartes `.pgm` dans Nav2 et la découverte réseau locale rapide via Cyclone DDS :

```zsh
# ==============================================================================
# ROS 2 JAZZY (macOS Apple Silicon)
# ==============================================================================
export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"

# Chargement de ROS 2 Jazzy (inclut Gazebo Harmonic et RViz2)
source "$(brew --prefix ros2-jazzy)/setup.zsh"

# Correctif GraphicsMagick pour la lecture des cartes .pgm dans Nav2 (map_server)
export DYLD_LIBRARY_PATH="$(brew --prefix graphicsmagick)/lib:$DYLD_LIBRARY_PATH"

# Autocomplétion de colcon
autoload -U bashcompinit && bashcompinit
eval "$(register-python-argcomplete colcon)"

# Cyclone DDS : middleware le plus fiable pour les gros lancements (Nav2, MoveIt)
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Mode A : Tous les nœuds tournent en local sur ce Mac (interface loopback lo0)
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'

# Mode B : Communication avec d'autres machines/robots sur le réseau local
# Remplacer lo0 par votre interface réseau (trouvée via : route get default | grep interface, en0 normalement)
# export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="en0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'

# Chargement automatique de votre workspace s'il existe
[[ -f "\(HOME/ros2_ws/install/local_setup.zsh" ]] && source "\)HOME/ros2_ws/install/local_setup.zsh"
# ==================== END ROS2 ======================
```

Rechargez ensuite votre configuration :
```bash
source ~/.zshrc
```

---

## 5. Vérification de l'installation

Ouvrez un **nouveau terminal** et exécutez ces commandes de contrôle :

```bash
# 1. Vérifier que le bon interpréteur Python est actif
which python3
# Résultat attendu : /Library/Frameworks/Python.framework/Versions/3.11/bin/python3

# 2. Vérifier que la CLI ROS 2 démarre sans erreur de module manquant
ros2 --help

# 3. Tester l'interface graphique RViz2
rviz2
```

---

## 6. Désinstallation propre

Si vous souhaitez supprimer complètement ROS 2 Jazzy et Python 3.11 de votre Mac :

### A. Supprimer ROS 2 et le tap Homebrew
```bash
brew uninstall ros2-jazzy
brew untap idesign0/ros2
```

### B. Supprimer Python 3.11 (Python.org)
```bash
sudo rm -rf /Library/Frameworks/Python.framework/Versions/3.11 "/Applications/Python 3.11"
sudo find /usr/local/bin -lname '/Library/Frameworks/Python.framework/Versions/3.11/*' -delete
```

### C. Nettoyer les caches et la configuration shell
* Supprimez les dossiers utilisateur `~/.ros`, `~/Library/Caches/pip` et votre workspace `~/ros2_ws`.
* Retirez le bloc `# ROS 2 JAZZY` dans **`~/.zshrc`** ainsi que le bloc `Setting PATH for Python 3.11` ajouté par l'installeur `.pkg` dans **`~/.zprofile`**.
