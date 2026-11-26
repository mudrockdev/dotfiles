//@ pragma UseQApplication
//@ pragma IconTheme Mint-Y-Aqua
// Giriş yöntemi eklentileri (fcitx5-qt6, ibus) panel sürecine yüklenmesin: popup'ları bozuyorlar.
// Panel yalnızca Wayland text-input kullanır; fcitx diğer uygulamalarda çalışmaya devam eder.
//@ pragma Env QT_IM_MODULE=wayland
//@ pragma Env QT_IM_MODULES=wayland

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
