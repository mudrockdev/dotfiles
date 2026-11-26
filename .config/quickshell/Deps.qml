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
            why: "App windows, previews, Bluetooth pairing",
            test: "command -v python3"
        },
        {
            id: "python3-dbus",
            name: "Python dbus module",
            pkg: "python3-dbus",
            why: "Bluetooth pairing (PIN / code confirmation)",
            test: "python3 -I -c 'import dbus, dbus.mainloop.glib, dbus.service'"
        },
        {
            id: "python3-gobject",
            name: "Python GLib (gi) module",
            pkg: "python3-gobject-base",
            why: "Bluetooth pairing (PIN / code confirmation)",
            test: "python3 -I -c 'from gi.repository import GLib'"
        },
        {
            id: "nmcli",
            name: "nmcli",
            pkg: "NetworkManager",
            why: "VPN connections, watching network changes",
            test: "command -v nmcli"
        },
        {
            id: "ip",
            name: "ip",
            pkg: "iproute",
            why: "IP addresses in the network menu",
            test: "command -v ip"
        },
        {
            id: "rfkill",
            name: "rfkill",
            pkg: "util-linux",
            why: "Airplane mode",
            test: "command -v rfkill"
        },
        {
            id: "systemd",
            name: "loginctl / systemctl",
            pkg: "systemd",
            why: "Lock and suspend",
            test: "command -v loginctl && command -v systemctl"
        },
        {
            id: "cosmic-settings",
            name: "cosmic-settings",
            pkg: "cosmic-settings",
            why: "Settings shortcuts",
            test: "command -v " + Config.settingsCommand[0]
        },
        {
            id: "cosmic-app-library",
            name: "cosmic-app-library",
            pkg: "cosmic-app-library",
            why: "App launcher button",
            test: "command -v " + Config.launcherCommand[0]
        },
        {
            id: "cosmic-osd",
            name: "cosmic-osd",
            pkg: "cosmic-osd",
            why: "Log out / restart / shut down confirmation",
            test: "command -v cosmic-osd"
        },
        {
            id: "cosmic-monitor",
            name: "cosmic-monitor",
            pkg: "cosmic-monitor",
            why: "Opens when clicking the system monitor",
            test: "command -v " + Config.systemMonitorCommand[0]
        },
        {
            id: "icons",
            name: iconTheme + " icon theme",
            pkg: "mint-y-icons",
            why: "Panel icons",
            test: "root.themeTest"
        },
        {
            id: "adwaita",
            name: "Adwaita icon theme",
            pkg: "adwaita-icon-theme",
            why: "Some symbolic icons (airplane mode, VPN…)",
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
