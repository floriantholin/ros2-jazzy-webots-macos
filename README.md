# ROS 2 Jazzy & Webots en natif sur macOS (Apple Silicon — testé sur macOS 27.2)

> **Plateforme :** Apple Silicon (`arm64`) · **OS :** macOS 15 – 27.2 (testé sur 27.2) · **ROS 2 :** Jazzy Jalisco · **Python :** 3.11 (`python.org`)


Ce dépôt regroupe les **guides d'installation** et les **scripts d'automatisation** permettant de faire tourner **ROS 2 Jazzy** (RViz2, Nav2, MoveIt 2, Gazebo Harmonic) et le simulateur **Webots** en natif sur Mac Apple Silicon (`arm64`), sans machine virtuelle ni Docker.

---

## Pourquoi ce dépôt ? (Les blocages de l'installation de base)

Installer simplement `brew install ros2-jazzy` et télécharger le `.dmg` officiel de Webots sur un Mac Apple Silicon récent (macOS 27.2) entraîne une série d'erreurs bloquantes. Ce dépôt automatise tous les correctifs nécessaires :

| Problème rencontré avec l'installation de base | Cause technique | Solution apportée par ce dépôt |
| :--- | :--- | :--- |
| **Webots refuse de démarrer** (*"Port 1234 is already in use"*) | Bug réseau sur **macOS 27** : la vérification TCP de Webots R2025a renvoie un faux positif sur tous les ports `1234-1244`. | Compilation de Webots depuis la branche `master` qui intègre le correctif `WbTcpServer.cpp`. |
| **Crash `ImportError` / architecture incompatible** au lancement des contrôleurs | Le binaire `webots-controller` du `.dmg` est compilé pour Intel (`x86_64`), ce qui force Python 3.11 sous Rosetta 2 alors que `ros2-jazzy` est `arm64`. | Compilation locale de Webots et de ses contrôleurs en **`arm64` natif**. |
| **`Library not loaded` (`libcar.dylib` / `rclpy`)** | La sécurité macOS (SIP) efface `DYLD_LIBRARY_PATH` lors du lancement des sous-processus contrôleurs. | Injection des chemins `@rpath` et signature ad-hoc (`codesign`) automatisées via CMake (`macos_post_install.cmake`). |
| **Crash immédiat du pont ROS 2** (*"Failed to open cmdline file"*) | `webots_ros2_driver` tente de lire `/proc/<pid>/cmdline`, un dossier spécifique à Linux qui n'existe pas sur macOS. | Patch automatique de `Driver.cpp` (`#ifndef __APPLE__`) et recompilation locale du driver. |
| **Le superviseur ROS 2 ne trouve pas Webots** (*"Cannot open directory /tmp/webots/..."*) | Webots sur macOS écrit dans `$TMPDIR` (`/var/folders/...`) alors que ROS 2 attend `/tmp/webots/$USER`. | Alignement des deux processus via `export WEBOTS_TMPDIR="/tmp/webots/$USER"`. |
| **Conflits Python, cartes Nav2 `.pgm` et lenteur réseau** | `webots_ros2_driver` exige Python 3.12 (au lieu de 3.11), Nav2 ne lit pas les `.pgm` sans GraphicsMagick et le multicast Wi-Fi ralentit DDS. | Adaptation CMake vers Python 3.11, export `DYLD_LIBRARY_PATH` pour GraphicsMagick et profil Cyclone DDS sur `lo0`. |


## Compatibilité matérielle et logicielle

| Composant | Support / Version requise | Notes |
| :--- | :--- | :--- |
| **Processeur** | **Apple Silicon (`arm64`) uniquement** (M1, M2, M3, M4) | Les Mac Intel (`x86_64`) ne sont pas supportés par le tap `idesign0/ros2`. |
| **Système d'exploitation** | **macOS 15 (Sequoia) à 27.2** *(testé sur 27.2)* | Inclut le correctif réseau TCP (`WbTcpServer.cpp`) et le contournement SIP (`@rpath` + `codesign`) pour macOS 27. |
| **Python** | **Python 3.11.x officiel (`python.org`)** | Framework `/Library/Frameworks/Python.framework/Versions/3.11` obligatoire (Homebrew/uv non supportés). |
| **ROS 2** | **Jazzy Jalisco** (`idesign0/homebrew-ros2`) | Keg-only via Homebrew, avec Cyclone DDS configuré sur `lo0`. |
| **Webots** | **Compilé depuis `master` (R2025b+)** | Génère `webots` et `webots-controller` en `arm64` natif. |

---

## Contenu du dossier

| Fichier | Rôle |
| :--- | :--- |
| **`INSTALL_ROS2_JAZZY.md`** | Guide détaillé pas à pas pour installer Python 3.11 et ROS 2 Jazzy via Homebrew. |
| **`INSTALL_WEBOTS_MACOS.md`** | Guide détaillé pour compiler Webots en natif (`arm64`) et patcher `webots_ros2_driver` pour macOS 27.2. |
| **`install_ros2_jazzy.sh`** | Script automatisé d'installation de ROS 2 Jazzy et de configuration de `~/.zshrc`. |
| **`install_webots_ros2.sh`** | Script automatisé de compilation de Webots et de `webots_ros2_driver` (avec signature `codesign` automatique). |
| **`fix_ros2_macos.sh`** | Script de maintenance rapide à lancer après chaque mise à jour (`brew upgrade ros2-jazzy`). |

---

## Démarrage rapide (Installation complète)

### 0. Prérequis manuels
1. **Mac Apple Silicon (`arm64`)** sous macOS.
2. **Xcode Command Line Tools :** `xcode-select --install`
3. **Homebrew** installé dans `/opt/homebrew`.
4. **Python 3.11 officiel** installé depuis [python.org](https://python.org) (installeur *macOS 64-bit universal2 .pkg*, suivi de `Install Certificates.command`).

### 1. Rendre les scripts exécutables
```bash
chmod +x install_ros2_jazzy.sh install_webots_ros2.sh fix_ros2_macos.sh
```

### 2. Installer ROS 2 Jazzy
```bash
./install_ros2_jazzy.sh ~/ros2_ws
source ~/.zshrc
```

### 3. Installer Webots et `webots_ros2_driver`
*(Ajoutez l'option `--clean` pour supprimer automatiquement les fichiers intermédiaires de compilation à la fin).*
```bash
./install_webots_ros2.sh ~/ros2_ws --clean
```
Ajoutez ensuite les **3 lignes `WEBOTS_HOME` / `WEBOTS_TMPDIR`** affichées à la fin du script dans votre `~/.zshrc`, puis rechargez votre terminal :
```bash
source ~/.zshrc
```

---

## Maintenance après mise à jour Homebrew

Lorsqu'une nouvelle version de `ros2-jazzy` est publiée sur Homebrew :
```bash
brew upgrade ros2-jazzy
./fix_ros2_macos.sh ~/ros2_ws
```
*(Ajoutez `--rebuild` si vous souhaitez également recompiler `webots_ros2_driver`).*

---

## Crédits et remerciements

Ce dépôt s'appuie sur le travail open source des projets et mainteneurs suivants :

* **[idesign0/homebrew-ros2](https://github.com/idesign0/homebrew-ros2)** & **[idesign0/ros2_macOS](https://github.com/idesign0/ros2_macOS)** (par **idesign0**) — Pour la compilation et la distribution des paquets natifs **ROS 2 Jazzy** sur macOS Apple Silicon, ainsi que les recommandations de configuration (profil Cyclone DDS sur `lo0` et contournement GraphicsMagick pour Nav2).
* **[Cyberbotics Webots](https://github.com/cyberbotics/webots)** & **[webots_ros2](https://github.com/cyberbotics/webots_ros2)** — Pour le simulateur open source Webots, le correctif réseau TCP pour macOS 27 (`WbTcpServer.cpp`) et le pont ROS 2 `webots_ros2_driver`.
* **[DLu/tf_transformations](https://github.com/DLu/tf_transformations)** (par **David V. Lu!!**, basé sur les travaux de Christoph Gohlke et Matthew Brett) — Pour la bibliothèque de transformations spatiales sous ROS 2.
* **[Homebrew](https://brew.sh)** et la **Python Software Foundation** — Pour le gestionnaire de paquets macOS et la distribution framework de Python 3.11.
