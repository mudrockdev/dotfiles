# system and oh my bash
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

case $- in
  *i*) ;;
    *) return;;
esac

export OSH='/home/mudrock/.oh-my-bash'
export OSH_THEME="brainy"
export DISABLE_AUTO_UPDATE="true"
export OMB_PROMPT_SHOW_PYTHON_VENV=true

export completions=(
  git
  composer
  ssh
  pip3
)

export aliases=(
  general
)

export plugins=(
  git
  bashmarks
)

source "$OSH/oh-my-bash.sh"

# user

export PAGER="less"
export EDITOR="nano"

if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

shopt -s checkwinsize
shopt -s autocd # change to named directory
shopt -s cdspell # autocorrects cd misspellings
shopt -s cmdhist # save multi-line commands in history as single line
shopt -s dotglob # for mv * see hidden files
shopt -s histappend # do not overwrite history
shopt -s expand_aliases # expand aliases
bind -s 'set completion-ignore-case on' # make commands case-insensitive

alias c="clear"
alias services="sudo systemctl list-units --type=service --all"
alias grubmk="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias wget="wget -c"
alias grep='grep --color=auto'
alias ls="ls --color=auto"
alias leserver="ssh .."
alias neo="neowofetch"
alias mntjf="sudo mount -t nfs 192.168.1.200:/mnt/jellyfin-media /mnt/valen"
# shellcheck disable=SC2139
alias fpurge="flatpak uninstall --delete-data $1"

alias yarn="corepack yarn"
alias yarnpkg="corepack yarnpkg"
alias pnpm="corepack pnpm"
alias pnpx="corepack pnpx"

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
