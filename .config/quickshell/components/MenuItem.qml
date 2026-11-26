import QtQuick
import QtQuick.Layouts
import qs

// Popup içindeki satır.
Rectangle {
    id: root

    property string text: ""
    property string subtitle: ""        // metnin altında ikinci satır
    property string secondary: ""       // sağda soluk metin
    property string icon: ""
    property bool colorizeIcon: true
    property bool checked: false
    property string trailingIcon: ""    // ör. açılır bölüm oku
    // Üzerine gelince sağda görünen küçük düğme (ör. unut / kaldır)
    property string actionIcon: ""
    property string actionTooltip: ""
    readonly property bool hovered: ma.containsMouse || actionMa.containsMouse

    signal triggered
    signal actionTriggered

    Layout.fillWidth: true
    implicitWidth: rowL.implicitWidth + 16
    implicitHeight: subtitle !== "" ? 36 : 26
    radius: Theme.radius
    color: !enabled ? "transparent" : ma.pressed ? Theme.pressed : hovered ? Theme.hover : "transparent"
    opacity: enabled ? 1 : 0.5

    RowLayout {
        id: rowL
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 8

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            colorize: root.colorizeIcon
            color: root.checked ? Theme.accent : Theme.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.text
                color: root.checked ? Theme.accent : Theme.fg
            }
            Label {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize - 1
            }
        }
        Label {
            visible: root.secondary !== ""
            text: root.secondary
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
        }
        Icon {
            visible: root.trailingIcon !== ""
            icon: root.trailingIcon
            size: 12
            color: Theme.fgDim
        }
        // eylem düğmesi yer kaplasın ki üzerine gelince satır kaymasın
        Item {
            visible: root.actionIcon !== ""
            implicitWidth: 20
            implicitHeight: 20
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

    Rectangle {
        visible: root.actionIcon !== "" && root.hovered
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: Theme.r(Theme.radiusS, height)
        color: actionMa.pressed ? Theme.pressed : actionMa.containsMouse ? Theme.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            icon: root.actionIcon
            size: 14
            color: actionMa.containsMouse ? Theme.fg : Theme.fgDim
        }

        MouseArea {
            id: actionMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionTriggered()
        }
    }
}
