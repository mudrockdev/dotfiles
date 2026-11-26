import QtQuick
import QtQuick.Layouts
import qs

// Başlık + açma/kapama anahtarı.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string subtitle: ""
    property bool bold: true
    property bool checked: false

    signal toggled

    Layout.fillWidth: true
    implicitWidth: rowL.implicitWidth + 16
    implicitHeight: subtitle !== "" ? 38 : 30
    radius: Theme.radius
    color: ma.containsMouse ? Theme.hover : "transparent"

    RowLayout {
        id: rowL
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Icon {
            visible: root.icon !== ""
            icon: root.icon
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.text
                font.bold: root.bold
            }
            Label {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize - 1
            }
        }
        Rectangle {
            implicitWidth: 34
            implicitHeight: 18
            radius: Theme.r(Theme.radiusXl, height)
            color: root.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)

            Rectangle {
                width: 14
                height: 14
                radius: Theme.r(Theme.radiusXl, height)
                y: 2
                x: root.checked ? parent.width - width - 2 : 2
                color: "white"

                Behavior on x {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
