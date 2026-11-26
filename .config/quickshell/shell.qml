//@ pragma UseQApplication
//@ pragma IconTheme Mint-Y-Aqua

// COSMIC panelini taklit eden Quickshell paneli.
// Çalıştırma: qs  (veya: qs -p ~/.config/quickshell)

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
