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
    // Dosya okunana kadar hiçbir şey yazılmaz; yoksa açılışta varsayılanlar kayıtlı ayarların üstüne yazılır
    property bool loaded: false

    FileView {
        // Sabit konum: Quickshell.statePath yapılandırmanın yoluna göre değişiyor
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-panel/settings.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: if (root.loaded)
            writeAdapter()
        onLoaded: root.loaded = true
        onLoadFailed: error => {
            // Dosya yoksa oluştur; bozuksa üstüne yazma (ayarlar bu oturumda kaydedilmez)
            if (error === FileViewError.FileNotFound) {
                root.loaded = true;
                writeAdapter();
            } else {
                console.warn("Settings: could not read settings.json, changes will not be saved:", error);
            }
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
