# system and oh my bash
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

case $- in
  *i*) ;;
    *) return;;
esac

export OSH='/home/mudrock/.oh-my-bash'
export OSH_THEME="brainy" # brainy
export DISABLE_AUTO_UPDATE="true"
export OMB_PROMPT_SHOW_PYTHON_VENV=true

export completions=(
  git
  composer
  ssh
  pip3
  npm
  rake
  maven
  nvm
  tmux
  pip
)

export aliases=(
  general
)

export plugins=(
  git
  bashmarks
)

source "$OSH/oh-my-bash.sh"

export PAGER="less"
export EDITOR="nano"
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

export HISTFILE=/$HOME/.var/bash_history
export HISTCONTROL=ignoreboth
export HISTSIZE=1000
export HISTFILESIZE=2000

shopt -s checkwinsize
shopt -s autocd # change to named directory
shopt -s cdspell # autocorrects cd misspellings
shopt -s cmdhist # save multi-line commands in history as single line
shopt -s dotglob # for mv * see hidden files
shopt -s histappend # do not overwrite history
shopt -s expand_aliases # expand aliases
bind -s 'set completion-ignore-case on' # make commands case-insensitive

export PODMAN_COMPOSE_WARNING_LOGS=false

alias c="clear"
alias services="sudo systemctl list-units --type=service --all"
alias grubmk="sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
alias wget="wget -c"
alias grep='grep --color=auto'
alias ls="ls --color=auto"
alias neo="fastfetch"
alias mntjf="sudo mount -t nfs 192.168.1.200:/mnt/jellyfin-media /mnt/valen"
alias fpurge="flatpak uninstall --delete-data $1"
alias apu="sudo dnf up && flatpak update && flatpak uninstall --unused"
alias k="kubectl"
alias kk="k0s kubectl"
alias ff="fastfetch"
alias vpnon="sudo tailscale up --exit-node=100.78.190.126"
alias vpnoff="sudo tailscale up --exit-node="

sscosmicinteractive() {
  wl-copy < "$(cosmic-screenshot --interactive)"
}

sscosmicfull() {
  cosmic-screenshot --interactive=false
}

if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/go/bin" ]; then
    export PATH="$HOME/go/bin:$PATH"
fi

if [ -d "$HOME/.bun" ]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH=$BUN_INSTALL/bin:$PATH
fi

if [ -d "$HOME/Android" ]; then
    export ANDROID_HOME="$HOME/Android"
    export PATH="$PATH:$ANDROID_HOME/Sdk/emulator"
    export PATH="$PATH:$ANDROID_HOME/Sdk/platform-tools"
    export NDK_HOME="$HOME/Android/Sdk/ndk/28.0.12916984"
fi

if [ -d "$HOME/.config/nvm" ]; then
    export NVM_DIR="$HOME/.config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

if [ -d "$HOME/.var/.pyenv" ]; then
    export PYENV_ROOT="$HOME/.var/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - bash)"
fi

exists() {
  command -v "$1" >/dev/null 2>&1
}

setwacom() {
  if exists xsetwacom; then
    :
  else
    echo "You don't have xsetwacom"
    exit
    fi
  if exists xrandr; then
    :
  else
    echo "You don't have xrandr"
    exit
  fi

  MONITORPORTS=()
  WACOMDEVICEIDS=()
  CHOSENMONITOR=$1
  WACOMDEVICES=$(xsetwacom list devices)
  ACTIVEMONITORS=$(xrandr --listactivemonitors)

  lines=()
  while read -r line; do
    lines+=("$line")
  done <<< "$ACTIVEMONITORS"

  for line in "${lines[@]}"; do
    if [[ $line == *"Monitors"* ]]; then
        continue
    fi

    declare -a templine=()
    read -ra templine <<< "$line"
    MONITORPORTS+=("${templine[3]}")
  done

  lines=()
  while read -r line; do
    lines+=("$line")
  done <<< "$WACOMDEVICES"

  for line in "${lines[@]}"; do
    if [[ $line == *"Monitors"* ]]; then
        continue
    fi

    declare -a templine=()
    read -ra templine <<< "$line"
    WACOMDEVICEIDS+=("${templine[8]}")
  done

  if [[ $# -gt 0 ]]; then
    for deviceid in "${WACOMDEVICEIDS[@]}"; do
        xsetwacom --set "$deviceid" MapToOutput "${MONITORPORTS[$CHOSENMONITOR]}"
    done
  else
    for deviceid in "${WACOMDEVICEIDS[@]}"; do
        xsetwacom --set "$deviceid" MapToOutput "${MONITORPORTS[0]}"
    done
  fi
}
