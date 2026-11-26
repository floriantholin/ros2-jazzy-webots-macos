# ==============================================================================
# ROS 2 JAZZY (Mode activable/désactivable + Badge Powerlevel10k / Zsh standard)
# Usage : source /chemin/vers/ros2_env_toggle.zsh (remplace le bloc ROS 2 standard)
# Commandes : ros2_on | ros2_off | ros2_toggle
# Indicateur visuel : affiche automatiquement un badge « 🤖 ROS2 (jazzy) » à droite du prompt quand actif (Powerlevel10k ou Zsh standard).
# ==============================================================================

_load_ros2_env() {
  # Évite de recharger l'environnement deux fois dans le même terminal
  [[ -n "${ROS_DISTRO:-}" ]] && return

  local ws_dir="${ROS2_WS:-$HOME/ros2_ws}"
  local webots_dir="${WEBOTS_DIR:-$HOME/webots}"

  # 1. Python 3.11 officiel (python.org) requis pour pip3.11, rclpy et colcon
  export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"

  # 2. Chargement de ROS 2 Jazzy + correctif GraphicsMagick pour les cartes .pgm (Nav2)
  source "/opt/homebrew/opt/ros2-jazzy/setup.zsh" 2>/dev/null
  export DYLD_LIBRARY_PATH="/opt/homebrew/opt/graphicsmagick/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

  # 3. Autocomplétion de colcon (doit rester APRÈS setup.zsh)
  autoload -U bashcompinit && bashcompinit
  eval "$(register-python-argcomplete colcon)"

  # 4. Cyclone DDS : middleware recommandé sur macOS (boucle locale lo0, remplacer lo0 par en0 pour communiquer avec d'autres machines)
  #    ⚠️ Ne jamais combiner avec ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST ni ROS_LOCALHOST_ONLY
  export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo0" multicast="true"/></Interfaces></General><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'

  # 5 Workspace : source et se place à la racine si créé un nouveau terminal
  [[ "$PWD" == "$HOME" && -d "$ws_dir" ]] && cd "$ws_dir"
  [[ -f "$ws_dir/install/local_setup.zsh" ]] && source "$ws_dir/install/local_setup.zsh"

  # 6 Webots (compilé en natif)
  if [[ -d "$webots_dir/Contents" ]]; then
    export WEBOTS_HOME="$webots_dir/Contents"
    mkdir -p "/tmp/webots/$USER"
    export WEBOTS_TMPDIR="/tmp/webots/$USER"
  fi

  # 7. Alias pratiques
  alias src_workspace="source \"$ws_dir/install/local_setup.zsh\""
  alias colcon_build="(cd \"$ws_dir\" && colcon build) && src_workspace"
  alias colcon_build_symlink="(cd \"$ws_dir\" && colcon build --symlink-install) && src_workspace"
}

# Chargement automatique à l'ouverture d'un terminal si le mode ROS 2 est mémorisé
if [[ -f "$HOME/.ros2_enabled" ]]; then
  _load_ros2_env
fi

# Active ROS 2 dans le terminal courant ET mémorise l'état pour les futurs terminaux
ros2_on() {
  touch "$HOME/.ros2_enabled"
  _load_ros2_env
  (( $+functions[p10k] )) || echo "🤖 Mode ROS 2 Jazzy : ACTIVÉ"
}

# Désactive ROS 2 pour les futures fenêtres ET purge complètement l'environnement courant
ros2_off() {
  command -v ros2 &>/dev/null && ros2 daemon stop &>/dev/null
  rm -f "$HOME/.ros2_enabled"
  (( $+functions[p10k] )) || echo "💤 Mode ROS 2 Jazzy : DÉSACTIVÉ"
  exec env -i \
    HOME="$HOME" \
    USER="$USER" \
    LOGNAME="$LOGNAME" \
    SHELL="$SHELL" \
    TERM="$TERM" \
    COLORTERM="${COLORTERM:-}" \
    TMPDIR="$TMPDIR" \
    LANG="${LANG:-fr_FR.UTF-8}" \
    ITERM_SESSION_ID="${ITERM_SESSION_ID:-}" \
    ITERM_PROFILE="${ITERM_PROFILE:-}" \
    zsh -l
}

# Bascule rapidement entre activé et désactivé
ros2_toggle() {
  if [[ -f "$HOME/.ros2_enabled" ]]; then
    ros2_off
  else
    ros2_on
  fi
}

# Indicateur visuel (Powerlevel10k si installé, sinon prompt Zsh standard)
if (( $+functions[p10k] )); then
  prompt_ros2() {
    if [[ -n "${ROS_DISTRO:-}" ]]; then
      p10k segment -b blue -f white -i '🤖' -t "ROS2 ($ROS_DISTRO)"
    fi
  }
  typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS
  (( ${POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[(Ie)ros2]} )) || POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(ros2)
else
  setopt PROMPT_SUBST
  RPROMPT='${ROS_DISTRO:+%F{blue\}[🤖 ROS2 ($ROS_DISTRO)]%f }'"${RPROMPT:-}"
fi
# ==================== END ROS2 ======================
