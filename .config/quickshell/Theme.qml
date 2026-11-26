pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Renkler. Accent rengi COSMIC karanlık temasından okunur.
Singleton {
    id: root

    readonly property color panelBg: Qt.rgba(0.106, 0.106, 0.106, Config.panelOpacity)
    readonly property color popupBg: Qt.rgba(0.137, 0.137, 0.137, 0.97)
    readonly property color fg: "#f2f2f2"
    readonly property color fgDim: "#a6a6a6"
    readonly property color hover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.22)
    readonly property color border: Qt.rgba(1, 1, 1, 0.10)
    readonly property color separator: Qt.rgba(1, 1, 1, 0.08)
    property color accent: "#e51e21"

    // minimon benzeri renkler
    readonly property color cpu: "#ff5f56"
    readonly property color temp: "#ff9f43"
    readonly property color mem: "#36c5d6"
    readonly property color netDown: "#4aa3ff"
    readonly property color netUp: "#4cd964"

    readonly property int fontSize: 12
    readonly property int radius: 6

    FileView {
        path: Quickshell.env("HOME") + "/.config/cosmic/com.system76.CosmicTheme.Dark.Builder/v1/accent"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const r = /red:\s*([\d.]+)/.exec(t);
            const g = /green:\s*([\d.]+)/.exec(t);
            const b = /blue:\s*([\d.]+)/.exec(t);
            if (r && g && b)
                root.accent = Qt.rgba(parseFloat(r[1]), parseFloat(g[1]), parseFloat(b[1]), 1);
        }
    }
}
