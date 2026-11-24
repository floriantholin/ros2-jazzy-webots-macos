# ROS 2 Jazzy & Webots en natif sur macOS (Apple Silicon)

> **Plateforme :** Apple Silicon (`arm64`) · **OS :** macOS 15 / 26 / 27.2+ · **ROS 2 :** Jazzy Jalisco · **Python :** 3.11 (`python.org`)


Ce dépôt regroupe les **guides d'installation** et les **scripts d'automatisation** permettant de faire tourner **ROS 2 Jazzy** (RViz2, Nav2, MoveIt 2, Gazebo Harmonic) et le simulateur **Webots** en natif sur Mac Apple Silicon (`arm64`), sans machine virtuelle ni Docker.

---

## Compatibilité matérielle et logicielle

| Composant | Support / Version requise | Notes |
| :--- | :--- | :--- |
| **Processeur** | **Apple Silicon (`arm64`) uniquement** (M1, M2, M3, M4) | Les Mac Intel (`x86_64`) ne sont pas supportés par le tap `idesign0/ros2`. |
| **Système d'exploitation** | **macOS 15 (Sequoia) à macOS 27.2+** | Inclut le correctif réseau TCP (`WbTcpServer.cpp`) et le contournement SIP (`@rpath` + `codesign`) pour macOS 27. |
| **Python** | **Python 3.11.x officiel (`python.org`)** | Framework `/Library/Frameworks/Python.framework/Versions/3.11` obligatoire (Homebrew/uv non supportés). |
| **ROS 2** | **Jazzy Jalisco** (`idesign0/homebrew-ros2`) | Keg-only via Homebrew, avec Cyclone DDS configuré sur `lo0`. |
| **Webots** | **Compilé depuis `master` (R2025b+)** | Génère `webots` et `webots-controller` en `arm64` natif. |

---

## Contenu du dossier

| Fichier | Rôle |
| :--- | :--- |
| **`INSTALL_ROS2_JAZZY.md`** | Guide détaillé pas à pas pour installer Python 3.11 et ROS 2 Jazzy via Homebrew. |
| **`INSTALL_WEBOTS_MACOS.md`** | Guide détaillé pour compiler Webots en natif (`arm64`) et patcher `webots_ros2_driver` pour macOS 27+. |
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
