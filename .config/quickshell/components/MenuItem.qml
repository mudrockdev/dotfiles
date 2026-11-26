import QtQuick
import QtQuick.Layouts
import qs

// Popup içindeki satır.
Rectangle {
    id: root

    property string text: ""
    property string secondary: ""
    property string icon: ""
    property bool colorizeIcon: true
    property bool checked: false

    signal triggered

    Layout.fillWidth: true
    implicitWidth: rowL.implicitWidth + 16
    implicitHeight: 30
    radius: Theme.radius
    color: !enabled ? "transparent" : ma.pressed ? Theme.pressed : ma.containsMouse ? Theme.hover : "transparent"
    opacity: enabled ? 1 : 0.5

    RowLayout {
        id: rowL
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            colorize: root.colorizeIcon
            color: root.checked ? Theme.accent : Theme.fg
        }
        Label {
            Layout.fillWidth: true
            text: root.text
            color: root.checked ? Theme.accent : Theme.fg
        }
        Label {
            visible: root.secondary !== ""
            text: root.secondary
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
