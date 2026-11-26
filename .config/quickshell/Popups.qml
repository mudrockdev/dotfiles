pragma Singleton

import QtQuick
import Quickshell

// Aynı anda tek popup açık kalsın; panelde bir butona basınca açık popup kapansın.
// (Wayland popup grab'ı yalnızca başka uygulamalara tıklanınca kapatır,
// panelin kendisine yapılan tıklamalar popup'ı kapatmaz.)
Singleton {
    id: root

    property var current: null
    // Son basışta kapatılan popup (yoksa null). Aynı butonun popup'ı
    // basışta kapandıysa tıklamada yeniden açılmasın diye kullanılır.
    property var justClosed: null

    function closeCurrent() {
        if (current && current.visible) {
            justClosed = current;
            current.visible = false;
            expire.restart();
        } else {
            justClosed = null;
        }
    }

    // Bayrak yalnızca aynı tıklama için geçerli; takılı kalıp sonraki menüleri engellemesin
    Timer {
        id: expire
        interval: 600
        onTriggered: root.justClosed = null
    }
}
