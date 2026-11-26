[English](./RMW_NETWORKING.en.md) | **[Français](./RMW_NETWORKING.md)**

# Guide des Middlewares ROS 2 (RMW) : macOS, Simulation & Robot réel (Raspberry Pi)

Dans **ROS 2 Jazzy**, la communication entre les nœuds repose sur une couche d'abstraction appelée **RMW** (*ROS Middleware*). Le choix et la configuration du RMW déterminent la stabilité de la simulation sur macOS (Webots, RViz2, Nav2) ainsi que la fiabilité de la liaison Wi-Fi avec la voiture réelle (Raspberry Pi sous Ubuntu Server).

---

## 1. Comparatif des 3 middlewares disponibles sous ROS 2 Jazzy

| Middleware | Variable `RMW_IMPLEMENTATION` | Points forts | Limites et pièges |
| :--- | :--- | :--- | :--- |
| **FastDDS** *(défaut Ubuntu)* | `rmw_fastrtps_cpp` | Installé par défaut sur Ubuntu ; fonctionne sans configuration sur un réseau filaire simple. | **Instable sur macOS** dès qu'il y a beaucoup de nœuds ou de gros capteurs (LiDAR/caméra) à cause de la mémoire partagée POSIX et des limites de ports en mode `LOCALHOST`. |
| **CycloneDDS** *(recommandé en DDS)* | `rmw_cyclonedds_cpp` | Très rapide et léger ; contourne les bugs mémoire de macOS grâce au profil XML (`lo0` / `en0`) ; **interopérable avec FastDDS** sur le réseau. | Comme tout protocole DDS, il repose sur le **multicast UDP**, souvent filtré ou ralenti par les routeurs Wi-Fi publics ou de compétition. |
| **Zenoh** *(idéal en Wi-Fi contraint)* | `rmw_zenoh_cpp` | Remplace DDS par du **TCP/UDP routé** : insensible au blocage du multicast Wi-Fi, latence maîtrisée, idéal entre un Mac et une Raspberry Pi. | Nécessite de lancer un routeur (`rmw_zenohd`) ; **incompatible avec DDS** (toutes les machines doivent utiliser Zenoh). |

---

## 2. Configuration 1 : Simulation 100 % locale sur macOS (Webots + RViz2)

Sur macOS, le mode standard `export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` sature au-delà d'une douzaine de nœuds (Webots + bridge + TF + RViz2 + contrôleurs) et souffre de fuites de mémoire partagée avec FastDDS.

### Configuration recommandée (`~/.zshrc`)
Utilisez **CycloneDDS** forcé sur l'interface de bouclage locale (`lo0`) avec allocation dynamique des ports (`ParticipantIndex=none`) :

```zsh
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'
```

> ⚠️ **Règle d'or :** Ne combinez **jamais** `CYCLONEDDS_URI` avec `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` ou `ROS_LOCALHOST_ONLY=1` : ces variables entrent en conflit et bloquent la découverte des nœuds.

---

## 3. Configuration 2 : Liaison Mac ↔ Voiture (Raspberry Pi Ubuntu Server)

### Option A — Mode DDS standard (compatible avec toute l'équipe Ubuntu)
CycloneDDS et FastDDS utilisent le même standard réseau DDS, mais la communication entre eux n'est pas garantie, à éviter.

1. **Sur la Raspberry Pi (`~/.bashrc`) :**
   Installez CycloneDDS via `sudo apt install ros-jazzy-rmw-cyclonedds-cpp`.
2. **Sur le Mac (`~/.zshrc`) :**
   Basculez CycloneDDS de `lo0` vers votre carte Wi-Fi (généralement `en0`, vérifiable via `route get default | grep interface`) :
   ```zsh
   export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
   export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="en0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'
   ```

Rq : FastDDS marche aussi mais est souvent moins performant.

---

### Option B — Mode Zenoh (si le Wi-Fi bloque le multicast ou sature)
À privilégier sur piste si le réseau Wi-Fi filtre les paquets multicast UDP ou si le flux LiDAR fait chuter la connexion.

1. **Sur la Raspberry Pi (Ubuntu Server) :**
   ```bash
   sudo apt update && sudo apt install -y ros-jazzy-rmw-zenoh-cpp
   ```
   Ajoutez dans `~/.bashrc` de la Pi :
   ```bash
   export RMW_IMPLEMENTATION=rmw_zenoh_cpp
   ```
   Lancez le routeur Zenoh sur la voiture (à garder actif ou à lancer via un service `systemd`) :
   ```bash
   ros2 run rmw_zenoh_cpp rmw_zenohd
   ```

2. **Sur le Mac :**
   *(Inclus par défaut dans `ros2-jazzy` via Homebrew).* Remplacez `<IP_RASPBERRY_PI>` par l'adresse IP de la voiture (ex. `192.168.1.50`) :
   ```zsh
   unset CYCLONEDDS_URI
   export RMW_IMPLEMENTATION=rmw_zenoh_cpp
   export ZENOH_CONFIG_OVERRIDE='connect/endpoints=["tcp/<IP_RASPBERRY_PI>:7447"]'
   ```

---

## 4. Checklist terrain avant un essai sur piste (Raspberry Pi)

* **1. Même `ROS_DOMAIN_ID` :** Vérifiez que `echo $ROS_DOMAIN_ID` renvoie la même valeur (ex. `0`) sur le Mac et sur la Raspberry Pi.
* **2. Synchronisation des horloges (vital pour TF2 et RViz2) :** Une Raspberry Pi sans accès Internet dérive rapidement. Si les horloges ont plus de quelques millisecondes d'écart, RViz2 rejette les transformations (`TF_OLD_DATA` / `Extrapolation Error`). Installez `chrony` (`sudo apt install -y chrony`) sur la Pi pour synchroniser son heure sur le Mac ou le routeur.
* **3. Pare-feu Ubuntu (`ufw`) :** Assurez-vous qu'il ne bloque pas les ports ROS 2 (`sudo ufw status`). En cas d'activation, autorisez le port `7447/tcp` (Zenoh) ou la plage `7400:7500/udp` (DDS).
* **4. Réseau dédié :** Configurez la Raspberry Pi en **Hotspot Wi-Fi** (point d'accès direct) lors des essais sur piste afin d'éviter la saturation des réseaux publics.

---

## 5. Commandes de diagnostic rapide

```bash
# 1. Vérifier quel RMW est actuellement actif dans le terminal
ros2 doctor --report | grep -i "middleware"

# 2. Tester si le multicast UDP passe entre deux machines (lancer sur les deux PC en même temps)
ros2 multicast receive   # Sur le Mac
ros2 multicast send      # Sur la Raspberry Pi

# 3. Lister les nœuds visibles sur le réseau
ros2 node list
```
