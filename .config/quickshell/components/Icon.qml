import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs

// Tema ikonu. colorize=true ise (sembolik ikonlar) tek renge boyanır.
Item {
    id: root

    property string icon: ""
    property string fallback: "image-missing"
    property color color: Theme.fg
    property bool colorize: true
    property int size: 16

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        asynchronous: true
        source: {
            const i = root.icon;
            if (i === "")
                return Quickshell.iconPath(root.fallback, true);
            if (i.startsWith("/"))
                return "file://" + i;
            if (i.includes("://"))
                return i;
            return Quickshell.iconPath(i, root.fallback);
        }
        // Sembolik ikonu tek renge boya (önce beyaza çek, sonra renklendir).
        // QtQuick.Effects qt6-qtdeclarative ile gelir; ek bağımlılık yok.
        layer.enabled: root.colorize
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: root.color
        }
    }
}
