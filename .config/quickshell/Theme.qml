pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Renkler. Accent rengi COSMIC karanlık temasından okunur.
Singleton {
    id: root

    // Panelden seçilen tema (Settings.theme): "default" | "azurlane"
    readonly property var themes: [
        // icon: menüdeki kare ikon; logo: varsa başlatıcıda ikon yerine gösterilen geniş görsel
        { id: "default", name: "Default", icon: "view-app-grid-symbolic", colorize: true, logo: "" },
        { id: "azurlane", name: "Azur Lane", icon: Qt.resolvedUrl("assets/al-anchor.svg"), colorize: false, logo: Qt.resolvedUrl("assets/al.svg"), logoAspect: 1660 / 964 }
    ]
    readonly property string name: Settings.theme
    readonly property bool azur: name === "azurlane"

    // Uygulama başlatıcı: logo varsa o, yoksa (boyanabilir) tema ikonu
    readonly property var current: themes.find(t => t.id === name) ?? themes[0]
    readonly property string launcherLogo: current.logo
    readonly property real launcherLogoAspect: current.logoAspect ?? 1
    // Tema seçici düğmesinin ekrandaki yatay merkezi, ekran adına göre (sarkan çapa buradan asılır)
    property var selectorX: ({})
    readonly property string launcherIcon: current.icon
    readonly property bool launcherIconColorize: current.colorize

    readonly property color panelBg: azur ? Qt.rgba(0.04, 0.08, 0.20, Math.max(Config.panelOpacity, 0.75)) : Qt.rgba(0.106, 0.106, 0.106, Config.panelOpacity)
    readonly property color popupBg: azur ? Qt.rgba(0.05, 0.09, 0.22, 0.97) : Qt.rgba(0.137, 0.137, 0.137, 0.97)
    readonly property color fg: "#f2f2f2"
    readonly property color fgDim: azur ? "#9fb4dc" : "#a6a6a6"
    readonly property color hover: azur ? Qt.rgba(0.31, 0.55, 1, 0.20) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color pressed: azur ? Qt.rgba(0.31, 0.55, 1, 0.35) : Qt.rgba(1, 1, 1, 0.22)
    readonly property color border: azur ? Qt.rgba(0.31, 0.55, 1, 0.35) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color separator: azur ? Qt.rgba(0.31, 0.55, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
    // Varsayılan temada COSMIC accent rengi, Azur Lane'de sabit mavi
    property color cosmicAccent: "#e51e21"
    readonly property color accent: azur ? "#4f8bff" : cosmicAccent

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
                root.cosmicAccent = Qt.rgba(parseFloat(r[1]), parseFloat(g[1]), parseFloat(b[1]), 1);
        }
    }
}
