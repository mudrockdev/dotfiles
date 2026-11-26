import QtQuick
import QtQuick.Layouts
import qs

// Basit yatay kaydırıcı (0..1).
Item {
    id: root

    property real value: 0
    signal moved(real value)

    Layout.fillWidth: true
    implicitWidth: 160
    implicitHeight: 20

    function setFromX(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.2)

        Rectangle {
            width: parent.width * Math.min(1, root.value)
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(1, root.value) * (root.width - width)
        color: "white"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.setFromX(mouse.x);
        }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
