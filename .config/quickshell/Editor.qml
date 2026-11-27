pragma Singleton

import QtQuick
import Quickshell

// Panel düzenleme modu (panel boşluğuna sağ tık > "Edit panel").
// Açıkken sabitlenmiş başlatıcılar sürüklenerek yeniden sıralanabilir.
// Değişiklikler anında kaydedilir; "Cancel" düzenleme başındaki hale döndürür.
Singleton {
    id: root

    property bool active: false
    // Düzenlemeye başlarken başlatıcıların sırası (Cancel bunu geri yükler)
    property var savedFavorites: []

    function start() {
        if (root.active)
            return;
        root.savedFavorites = Config.favorites.slice();
        root.active = true;
    }

    function finish() {
        root.active = false;
    }

    function cancel() {
        if (!root.active)
            return;
        root.active = false;
        if (root.savedFavorites.join("\n") !== Config.favorites.join("\n"))
            Config.setFavorites(root.savedFavorites);
    }
}
