pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Kullanıcı ayarları. COSMIC'teki favorileri doğrudan COSMIC App List
// config dosyasından okur, böylece iki panel senkron kalır.
Singleton {
    id: root

    // --- Panel (COSMIC: size Custom(24), opacity 0.5, anchor Top) ---
    readonly property int barHeight: 24
    readonly property real panelOpacity: 0.5

    // --- Komutlar ---
    readonly property var launcherCommand: ["cosmic-app-library"]
    readonly property var systemMonitorCommand: ["cosmic-monitor"]
    readonly property var settingsCommand: ["cosmic-settings"]

    readonly property var powerCommands: ({
        lock: ["loginctl", "lock-session"],
        suspend: ["systemctl", "suspend"],
        logout: ["cosmic-osd", "log-out"],
        reboot: ["cosmic-osd", "restart"],
        shutdown: ["cosmic-osd", "shutdown"]
    })

    // --- Saat (Qt.locale() ile; tr_TR -> "26 Kas 22:41:28") ---
    readonly property string clockFormat: "d MMM HH:mm:ss"

    // --- Sistem monitörü ---
    // hwmon "name" değerleri, ilk bulunan kullanılır.
    readonly property var tempSensors: ["k10temp", "zenpower", "coretemp", "cpu_thermal"]
    // Bu önekle başlayan arayüzler ağ hızına dahil edilmez.
    readonly property var netIgnorePrefixes: ["lo", "veth", "docker", "br-", "virbr", "tailscale", "tun", "wg", "vnet"]

    // --- Favoriler (sabitlenmiş başlatıcılar) ---
    // Kendi ayar dosyamızda (Settings.favorites) tutulur; COSMIC paneline yazılmaz.
    // İlk çalıştırmada COSMIC App List favorileri bir kez içe aktarılır (salt okunur).
    readonly property string cosmicFavoritesPath: Quickshell.env("HOME") + "/.config/cosmic/com.system76.CosmicAppList/v1/favorites"
    // COSMIC favori dosyası da yoksa ilk liste
    readonly property var fallbackFavorites: ["firefox", "org.gnome.Nautilus", "com.system76.CosmicSettings"]
    readonly property var favorites: Settings.favorites
    // İçe aktarma bitmeden yazmak listeyi ezebilir; o zamana kadar değişiklik yok.
    readonly property bool favoritesReady: Settings.favoritesImported

    function parseFavorites(text) {
        const ids = [];
        const re = /"((?:[^"\\]|\\.)*)"/g;
        let m;
        while ((m = re.exec(text)) !== null)
            ids.push(m[1].replace(/\\(.)/g, "$1"));
        return ids;
    }

    function setFavorites(ids) {
        if (!root.favoritesReady) {
            console.warn("Favorites not loaded yet, change ignored");
            return;
        }
        Settings.favorites = ids;
    }
    function pin(id) {
        if (!root.favorites.includes(id))
            setFavorites(root.favorites.concat([id]));
    }
    function unpin(id) {
        setFavorites(root.favorites.filter(f => f !== id));
    }

    // Tek seferlik içe aktarma
    FileView {
        path: Settings.favoritesImported ? "" : root.cosmicFavoritesPath
        printErrors: false
        onLoaded: {
            Settings.favorites = root.parseFavorites(text());
            Settings.favoritesImported = true;
        }
        onLoadFailed: {
            Settings.favorites = root.fallbackFavorites;
            Settings.favoritesImported = true;
        }
    }
}
