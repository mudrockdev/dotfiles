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

    // --- Favoriler ---
    readonly property string cosmicFavoritesPath: Quickshell.env("HOME") + "/.config/cosmic/com.system76.CosmicAppList/v1/favorites"
    readonly property var fallbackFavorites: ["firefox", "org.gnome.Nautilus", "com.system76.CosmicSettings"]
    property var favorites: fallbackFavorites

    FileView {
        path: root.cosmicFavoritesPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const ids = [];
            const re = /"([^"]+)"/g;
            let m;
            const t = text();
            while ((m = re.exec(t)) !== null)
                ids.push(m[1]);
            if (ids.length > 0)
                root.favorites = ids;
        }
    }
}
