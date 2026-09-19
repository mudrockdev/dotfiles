#!/usr/bin/env bash
# Set GTKG cursor theme to Chiharu / GTK looks for user and system themes
gsettings set org.gnome.desktop.interface cursor-theme Chiharu

# Set Qt cursor theme to Chiharu / Qt looks for user themes only
ln -s /usr/share/icons/default "$HOME/.local/share/icons/default"
