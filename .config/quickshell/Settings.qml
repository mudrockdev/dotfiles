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
    // Uygulama menüsü (whisker): favoriler (null = paneldeki başlatıcılar) ve son kullanılanlar
    property alias menuFavorites: adapter.menuFavorites
    property alias recentApps: adapter.recentApps
    // "list" | "grid"
    property alias menuLayout: adapter.menuLayout
    // Asılı çapa (yalnızca Azur Lane teması): açık mı, hangi ekranda
    property alias hangingAnchor: adapter.hangingAnchor
    property alias anchorScreen: adapter.anchorScreen
    // Boştayken hafifçe sallansın
    property alias anchorSwing: adapter.anchorSwing
    // Pencerelerin üstünde göster (kapalıyken yalnızca masaüstünde)
    property alias anchorOverApps: adapter.anchorOverApps
    // DeepSeek-chan (Live2D masaüstü karakteri, sağ altta): açık mı, ekran, pencerelerin üstünde mi, boy
    property alias deepseek: adapter.deepseek
    property alias deepseekScreen: adapter.deepseekScreen
    property alias deepseekOverApps: adapter.deepseekOverApps
    // "small" | "medium" | "large"
    property alias deepseekSize: adapter.deepseekSize
    // "upper" (belden yukarısı, ekran kenarı keser) | "full" (tüm boy)
    property alias deepseekFraming: adapter.deepseekFraming
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
            property var menuFavorites: null
            property var recentApps: []
            property string menuLayout: "list"
            property bool hangingAnchor: false
            property string anchorScreen: ""
            property bool anchorSwing: true
            property bool anchorOverApps: false
            property bool deepseek: false
            property string deepseekScreen: ""
            property bool deepseekOverApps: false
            property string deepseekSize: "medium"
            property string deepseekFraming: "upper"
        }
    }
}
