case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

shopt -s checkwinsize
shopt -s autocd # change to named directory
shopt -s cdspell # autocorrects cd misspellings
shopt -s cmdhist # save multi-line commands in history as single line
shopt -s dotglob
shopt -s histappend # do not overwrite history
shopt -s expand_aliases # expand aliases
bind -s 'set completion-ignore-case on' # make commands case-insensitive

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# aliasses
alias ff="fastfetch"
alias c="clear"
alias services="sudo systemctl list-units --type=service --all"
alias grubmk="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias wget="wget -c"
alias grep='grep --color=auto'
alias leserver="ssh ..."
# apt
alias apu="sudo apt update && sudo apt upgrade && flatpak update && flatpak remove --unused"
alias apr="sudo apt autoremove"
alias aps="apt list --installed"
alias apss="apt list --installed | grep"
alias apcr="apt-cache rdepends"
# other
alias neo="neofetch"
# alias neo="neofetch --ascii_distro ubuntu"

# needs reboot
fixrepos() {
if command -v resolvectl &> /dev/null
then
  sudo apt clean
  sudo resolvectl flush-caches
  sudo apt update
else
  sudo apt-get install -y systemd-resolved
  fixrepos
fi
}