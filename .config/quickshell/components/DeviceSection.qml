pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

// "Çıkış / Giriş" başlığı + seçili cihaz; tıklayınca cihaz listesi açılır.
ColumnLayout {
    id: root

    property string title: ""
    property var nodes: []
    property var current: null
    property bool expanded: false

    signal selected(var node)

    function nodeName(n) {
        return n ? (n.description || n.nickname || n.name) : "—";
    }

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + 10
        radius: Theme.radius
        color: headerMa.containsMouse ? Theme.hover : "transparent"

        ColumnLayout {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.fontSize + 1
            }
            Label {
                Layout.fillWidth: true
                text: root.nodeName(root.current)
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }

        MouseArea {
            id: headerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Repeater {
        model: root.expanded ? root.nodes : []

        delegate: Rectangle {
            id: dev
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: devLabel.implicitHeight + 14
            radius: Theme.radius
            color: devMa.containsMouse ? Theme.hover : "transparent"

            Label {
                id: devLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 32
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.nodeName(dev.modelData)
                wrapMode: Text.Wrap
                color: dev.modelData === root.current ? Theme.accent : Theme.fg
            }

            MouseArea {
                id: devMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selected(dev.modelData);
                    root.expanded = false;
                }
            }
        }
    }
}
