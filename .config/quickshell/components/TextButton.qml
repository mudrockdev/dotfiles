import QtQuick
import qs

// Metinli küçük düğme (COSMIC "standard" / "suggested" buton).
Rectangle {
    id: root

    property string text: ""
    property bool primary: false

    signal clicked

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 26
    radius: Theme.r(Theme.radiusXl, height)
    opacity: enabled ? 1 : 0.5
    color: {
        const base = primary ? Theme.accent : Qt.rgba(1, 1, 1, 0.10);
        if (!enabled)
            return base;
        if (ma.pressed)
            return primary ? Qt.darker(Theme.accent, 1.25) : Theme.pressed;
        if (ma.containsMouse)
            return primary ? Qt.lighter(Theme.accent, 1.15) : Theme.hover;
        return base;
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "white" : Theme.fg
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
