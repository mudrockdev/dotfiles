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

    // COSMIC köşe yarıçapları (Ayarlar > Masaüstü > Görünüm > Stil).
    // Varsayılanlar COSMIC "yuvarlak" stilidir; dosyadan okunur.
    property real radiusXs: 4
    property real radiusS: 8
    property real radiusM: 16
    property real radiusL: 32
    property real radiusXl: 160
    // Kullanım: popup = M, menü satırı / panel butonu = S, küçük öğeler = Xs, anahtar = Xl
    readonly property real radius: radiusS

    // Yarıçapı boyuta göre sınırla (ör. 160 -> tam yuvarlak)
    function r(radius, height) {
        return Math.min(radius, height / 2);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/cosmic/com.system76.CosmicTheme.Dark/v1/corner_radii"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const get = name => {
                const m = new RegExp(name + ":\\s*\\(\\s*([\\d.]+)").exec(t);
                return m ? parseFloat(m[1]) : undefined;
            };
            root.radiusXs = get("radius_xs") ?? root.radiusXs;
            root.radiusS = get("radius_s") ?? root.radiusS;
            root.radiusM = get("radius_m") ?? root.radiusM;
            root.radiusL = get("radius_l") ?? root.radiusL;
            root.radiusXl = get("radius_xl") ?? root.radiusXl;
        }
    }

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
