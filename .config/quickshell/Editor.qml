pragma Singleton

import QtQuick
import Quickshell

// Panel düzenleme modu (panel boşluğuna sağ tık > "Edit panel").
// Açıkken sabitlenmiş başlatıcılar sürüklenerek yeniden sıralanabilir.
Singleton {
    property bool active: false
}
