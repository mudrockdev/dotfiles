pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Çalışma zamanı bağımlılık denetimi. Eksik olanlar tepside uyarı olarak gösterilir.
// Paket adları Fedora depolarına göredir. Quickshell'in kendisi ve Qt modülleri
// burada yok: onlar eksikse kabuk zaten açılamaz.
Singleton {
    id: root

    // Simge teması shell.qml'deki "//@ pragma IconTheme" ile aynı olmalı.
    readonly property string iconTheme: "Mint-Y-Aqua"

    // id, ne, hangi paket, ne için, denetim (sh; başarısızsa eksik)
    readonly property var checks: [
        {
            id: "python3",
            name: "python3",
            pkg: "python3",
            why: "Uygulama pencereleri, önizlemeler, Bluetooth eşleştirme",
            test: "command -v python3"
        },
        {
            id: "python3-dbus",
            name: "Python dbus modülü",
            pkg: "python3-dbus",
            why: "Bluetooth eşleştirme (PIN / kod onayı)",
            test: "python3 -I -c 'import dbus, dbus.mainloop.glib, dbus.service'"
        },
        {
            id: "python3-gobject",
            name: "Python GLib (gi) modülü",
            pkg: "python3-gobject-base",
            why: "Bluetooth eşleştirme (PIN / kod onayı)",
            test: "python3 -I -c 'from gi.repository import GLib'"
        },
        {
            id: "nmcli",
            name: "nmcli",
            pkg: "NetworkManager",
            why: "VPN bağlantıları, ağ değişikliklerini izleme",
            test: "command -v nmcli"
        },
        {
            id: "ip",
            name: "ip",
            pkg: "iproute",
            why: "Ağ menüsündeki IP adresleri",
            test: "command -v ip"
        },
        {
            id: "rfkill",
            name: "rfkill",
            pkg: "util-linux",
            why: "Uçak modu",
            test: "command -v rfkill"
        },
        {
            id: "systemd",
            name: "loginctl / systemctl",
            pkg: "systemd",
            why: "Kilitleme ve askıya alma",
            test: "command -v loginctl && command -v systemctl"
        },
        {
            id: "cosmic-settings",
            name: "cosmic-settings",
            pkg: "cosmic-settings",
            why: "Ayarlar kısayolları",
            test: "command -v " + Config.settingsCommand[0]
        },
        {
            id: "cosmic-app-library",
            name: "cosmic-app-library",
            pkg: "cosmic-app-library",
            why: "Uygulama başlatıcı düğmesi",
            test: "command -v " + Config.launcherCommand[0]
        },
        {
            id: "cosmic-osd",
            name: "cosmic-osd",
            pkg: "cosmic-osd",
            why: "Oturumu kapat / yeniden başlat / kapat onayı",
            test: "command -v cosmic-osd"
        },
        {
            id: "cosmic-monitor",
            name: "cosmic-monitor",
            pkg: "cosmic-monitor",
            why: "Sistem monitörüne tıklayınca açılır",
            test: "command -v " + Config.systemMonitorCommand[0]
        },
        {
            id: "icons",
            name: iconTheme + " simge teması",
            pkg: "mint-y-icons",
            why: "Panel simgeleri",
            test: "root.themeTest"
        },
        {
            id: "adwaita",
            name: "Adwaita simge teması",
            pkg: "adwaita-icon-theme",
            why: "Bazı sembolik simgeler (uçak modu, VPN…)",
            test: "root.adwaitaTest"
        }
    ]

    // Simge teması XDG veri dizinlerinden birinde olmalı
    function themeDirTest(name) {
        return 'for d in "${XDG_DATA_HOME:-$HOME/.local/share}" $(printf %s "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr : " ") "$HOME/.icons"; do ' + '[ -f "$d/' + name + '/index.theme" ] || [ -f "$d/icons/' + name + '/index.theme" ] && exit 0; done; exit 1';
    }

    readonly property string script: checks.map(c => {
        const t = c.test === "root.themeTest" ? themeDirTest(iconTheme) : c.test === "root.adwaitaTest" ? themeDirTest("Adwaita") : c.test;
        return "(" + t + ") >/dev/null 2>&1 || echo " + c.id;
    }).join("\n")

    property var missing: []
    property bool checked: false
    readonly property var packages: [...new Set(missing.map(m => m.pkg))]
    readonly property string installCommand: packages.length ? "sudo dnf install " + packages.join(" ") : ""

    function check() {
        if (!proc.running)
            proc.running = true;
    }

    Process {
        id: proc
        running: true
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").filter(s => s !== "");
                root.missing = root.checks.filter(c => ids.includes(c.id));
                root.checked = true;
            }
        }
    }

    // Paket kurulunca uyarı kendiliğinden kalksın
    Timer {
        running: root.missing.length > 0
        repeat: true
        interval: 60000
        onTriggered: root.check()
    }
}
