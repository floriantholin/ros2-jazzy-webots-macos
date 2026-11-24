[English](./README.en.md) | **[Français](./README.md)**

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
| **Webots** | **Compilé depuis `master` (R2025a+)** | Génère `webots` et `webots-controller` en `arm64` natif. |


## Gestion des mises à jour et pérennité

Ce dépôt est conçu pour résister aux évolutions des trois composants dont il dépend (testé en **novembre 2026** sur **`macOS 27.2`**, **`ros2-jazzy 26.11.23.13`**, **Webots `R2025a`** et **`webots_ros2` `2025.0.1`**) :

| Composant | Ce qui se passe lors d'une mise à jour | Comment le dépôt s'adapte |
| :--- | :--- | :--- |
| **`ros2-jazzy`** *(Homebrew)* | `brew upgrade ros2-jazzy` remplace le répertoire de ROS 2, ce qui supprime le lien symbolique `lib/Contents` et les signatures `@rpath` / `codesign` des bibliothèques `.dylib`. | Exécutez **`./fix_ros2_macos.sh ~/ros2_ws`** pour restaurer immédiatement le lien et re-signer les bibliothèques en quelques secondes.<br>*(Ajoutez `--rebuild` en cas de mise à jour majeure des bibliothèques C++ pour recompiler le bridge).* |
| **`webots_ros2_driver`** *(Bridge ROS 2)* | Le code amont évolue pour les nouvelles versions de ROS 2 ou peut intégrer officiellement les correctifs macOS. | **1. Branche amont (`master`) :** ignore la branche de développement `master`/`rolling` pour rester 100 % compatible avec l'API Jazzy.<br>**2. Python flexible :** adapte automatiquement toute version `Python 3.x` demandée par CMake vers `3.11`.<br>**3. Patch défensif (`Driver.cpp`) :** s'ignore proprement sans erreur si Cyberbotics supprime la lecture de `/proc/` sur macOS. |
| **`Webots`** *(Simulateur)* | La branche `master` reçoit des mises à jour continues et intègre le correctif réseau TCP pour macOS 27 (`WbTcpServer.cpp`). | `install_webots_ros2.sh` compile la dernière version de `master` en **`arm64` natif** et génère les scripts relais attendus par ROS 2.<br>*(Si `master` présente un jour une régression macOS, il suffit de basculer sur un tag de release officielle intégrant le correctif TCP).* |

### Commandes de maintenance après un `brew upgrade`
```bash
brew upgrade ros2-jazzy
./fix_ros2_macos.sh ~/ros2_ws            # Mise à jour standard (re-signature + lien symbolique)
./fix_ros2_macos.sh ~/ros2_ws --rebuild  # Mise à jour majeure (recompile aussi webots_ros2_driver)
```

---

## Contenu du dossier

| Fichier | Rôle |
| :--- | :--- |
| **[`INSTALL_ROS2_JAZZY.md`](./INSTALL_ROS2_JAZZY.md)** | Guide détaillé pas à pas pour installer Python 3.11 et ROS 2 Jazzy via Homebrew. |
| **[`INSTALL_WEBOTS_MACOS.md`](./INSTALL_WEBOTS_MACOS.md)** | Guide détaillé pour compiler Webots en natif (`arm64`) et patcher `webots_ros2_driver` pour macOS 27.2. |
| **[`RMW_NETWORKING.md`](./RMW_NETWORKING.md)** | Guide des middlewares ROS 2 (CycloneDDS, FastDDS, Zenoh) pour macOS et Raspberry Pi. |
| **`install_ros2_jazzy.sh`** | Script automatisé d'installation de ROS 2 Jazzy et de configuration de `~/.zshrc`. |
| **`install_webots_ros2.sh`** | Script automatisé de compilation de Webots et de `webots_ros2_driver` (avec signature `codesign` automatique). |
| **[`ros2_env_toggle.zsh`](./ros2_env_toggle.zsh)** | Optionnel : chargement à la demande (`ros2_on` / `ros2_off` / `ros2_toggle`) + badge Powerlevel10k pour garder des terminaux rapides. Affiche automatiquement un badge `🤖 ROS2 (jazzy)` à droite du prompt quand il est actif (Powerlevel10k ou Zsh standard). |
| **`fix_ros2_macos.sh`** | Script de maintenance rapide à lancer après chaque mise à jour (`brew upgrade ros2-jazzy`). |
| **`uninstall_webots_ros2.sh`** | Script de désinstallation propre de Webots et de `webots_ros2_driver`. |
| **`uninstall_ros2_jazzy.sh`** | Script de désinstallation complète de ROS 2 Jazzy et de Python 3.11 (`python.org`). |

---

## Démarrage rapide (Installation complète)

### 0. Prérequis manuels
1. **Mac Apple Silicon (`arm64`)** sous macOS.
2. **Xcode Command Line Tools :** `xcode-select --install`
3. **Homebrew** installé dans `/opt/homebrew`.
4. **Python 3.11.9 officiel** (dernière version 3.11 avec installeur macOS) téléchargé depuis [python.org/downloads/release/python-3119](https://www.python.org/downloads/release/python-3119/) (*macOS 64-bit universal2 installer* `.pkg`). À la fin de l'installation, **double-cliquez sur `Install Certificates.command`** dans la fenêtre Finder qui s'ouvre automatiquement.

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

> ⏳ **Temps d'exécution :** le clonage et la compilation native de Webots prennent environ **10 à 20 minutes** selon votre puce Apple Silicon (M1 à M4) et sollicitent tous les cœurs CPU. *(Ajoutez `--clean` pour libérer l'espace disque des fichiers temporaires à la fin).*

```bash
./install_webots_ros2.sh ~/ros2_ws --clean
```
Rechargez ensuite votre terminal pour charger `WEBOTS_HOME` et `WEBOTS_TMPDIR` (ajoutés automatiquement dans `~/.zshrc`) :
```bash
source ~/.zshrc
```

> 💡 **Astuce performance (ouverture rapide des terminaux & badge Powerlevel10k) :**
> Charger ROS 2 (`source setup.zsh`) ralentit sensiblement l'ouverture de chaque nouveau terminal ou onglet. Pour éviter cela au quotidien, utilisez le fichier **[`ros2_env_toggle.zsh`](./ros2_env_toggle.zsh)** (remplacez le bloc `# ROS 2 JAZZY` de votre `~/.zshrc` par son contenu) :
> * **`ros2_on` / `ros2_off` / `ros2_toggle`** activent ou purgent complètement l'environnement ROS 2 à la demande (état mémorisé entre les terminaux via `~/.ros2_enabled`).
> * **Indicateur visuel à droite du prompt :** tant que ROS 2 est actif, le script affiche automatiquement un badge bleu **`🤖 ROS2 (jazzy)`** tout à droite de la ligne de commande (compatible avec le thème de prompt **[Powerlevel10k](https://github.com)** s'il est installé, ou avec le prompt Zsh standard).

---

## Désinstallation complète

Pour supprimer proprement l'ensemble de l'environnement (exécutez les scripts dans cet ordre) :

```bash
chmod +x uninstall_webots_ros2.sh uninstall_ros2_jazzy.sh

# 1. Désinstaller Webots en premier
./uninstall_webots_ros2.sh ~/ros2_ws

# 2. Désinstaller ROS 2 Jazzy et Python 3.11 en second (ajoutez --delete-ws pour effacer ~/ros2_ws)
./uninstall_ros2_jazzy.sh ~/ros2_ws
```

---

## Crédits et remerciements

Ce dépôt s'appuie sur le travail open source des projets et mainteneurs suivants :

* **[idesign0/homebrew-ros2](https://github.com/idesign0/homebrew-ros2)** & **[idesign0/ros2_macOS](https://github.com/idesign0/ros2_macOS)** (par **idesign0**) — Pour la compilation et la distribution des paquets natifs **ROS 2 Jazzy** sur macOS Apple Silicon, ainsi que les recommandations de configuration (profil Cyclone DDS sur `lo0` et contournement GraphicsMagick pour Nav2).
* **[Cyberbotics Webots](https://github.com/cyberbotics/webots)** & **[webots_ros2](https://github.com/cyberbotics/webots_ros2)** — Pour le simulateur open source Webots, le correctif réseau TCP pour macOS 27 (`WbTcpServer.cpp`) et le pont ROS 2 `webots_ros2_driver`.
* **[DLu/tf_transformations](https://github.com/DLu/tf_transformations)** (par **David V. Lu!!**, basé sur les travaux de Christoph Gohlke et Matthew Brett) — Pour la bibliothèque de transformations spatiales sous ROS 2.
* **[Homebrew](https://brew.sh)** et la **Python Software Foundation** — Pour le gestionnaire de paquets macOS et la distribution framework de Python 3.11.
* **[Google Gemini](https://google.com)** — Assistance au diagnostic des blocages macOS 27 (SIP/rpath, `/proc`, réseau DDS/Zenoh), ainsi qu'à la structuration des scripts et de la documentation.
