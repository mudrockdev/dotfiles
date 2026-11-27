pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Panelden değiştirilen kalıcı ayarlar ($XDG_STATE_HOME/quickshell-panel/settings.json).
Singleton {
    id: root

    property alias showMediaControls: adapter.showMediaControls
    // "default" | "azurlane"
    property alias theme: adapter.theme
    // Sabitlenmiş başlatıcılar (uygulama kimlikleri, sırayla)
    property alias favorites: adapter.favorites
    // İlk çalıştırmada COSMIC favorileri bir kez içe aktarıldı mı
    property alias favoritesImported: adapter.favoritesImported

    FileView {
        // Sabit konum: Quickshell.statePath yapılandırmanın yoluna göre değişiyor
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-panel/settings.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool showMediaControls: true
            property string theme: "default"
            property var favorites: []
            property bool favoritesImported: false
        }
    }
}
