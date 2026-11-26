import QtQuick
import QtQuick.Layouts
import qs

// Yatay kaydırıcı: 0..to aralığı, isteğe bağlı işaret çizgisi (ör. %100).
Item {
    id: root

    property real value: 0
    property real to: 1.0
    property real mark: -1
    property real step: 0.05
    readonly property real ratio: Math.max(0, Math.min(1, value / to))

    signal moved(real value)

    Layout.fillWidth: true
    implicitWidth: 160
    implicitHeight: 24

    function emitRatio(r) {
        root.moved(Math.max(0, Math.min(1, r)) * to);
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 7
        width: parent.width - 14
        height: 4
        radius: Theme.r(Theme.radiusXs, height)
        color: Qt.rgba(1, 1, 1, 0.2)

        Rectangle {
            width: parent.width * root.ratio
            height: parent.height
            radius: Theme.r(Theme.radiusXs, height)
            color: Theme.accent
        }
    }

    Rectangle {
        visible: root.mark > 0 && root.mark < root.to
        x: 7 + (root.width - 14) * root.mark / root.to
        y: parent.height / 2 + 6
        width: 1
        height: 5
        color: Theme.fgDim
    }

    Rectangle {
        width: 16
        height: 16
        radius: Theme.r(Theme.radiusXl, height)
        anchors.verticalCenter: parent.verticalCenter
        x: root.ratio * (root.width - width)
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.emitRatio((mouse.x - 7) / (width - 14))
        onPositionChanged: mouse => {
            if (pressed)
                root.emitRatio((mouse.x - 7) / (width - 14));
        }
        onWheel: wheel => root.moved(Math.max(0, Math.min(root.to, root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
