import QtQuick
import Qt5Compat.GraphicalEffects
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
        visible: !root.colorize
    }

    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.color
        visible: root.colorize
        cached: false
    }
}
