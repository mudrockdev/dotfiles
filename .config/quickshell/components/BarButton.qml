import QtQuick
import qs

// Panel üzerindeki tıklanabilir öğe (COSMIC applet butonu gibi).
Rectangle {
    id: root

    property bool active: false
    property color activeColor: Theme.hover
    property int hPadding: 6
    // 0: yok, 1: çalışıyor, 2: odakta (uygulama listesi için)
    property int indicator: 0
    readonly property alias hovered: ma.containsMouse
    default property alias content: row.data
    // Düğmenin tamamını kaplayan, iç MouseArea'nın üstündeki öğeler (ör. sürükleme alanı)
    property alias overlay: overlayItem.data

    // Popup içindeki butonlar açık popup'ı kapatmamalı
    function insidePopup() {
        for (let p = root.parent; p; p = p.parent)
            if (p.objectName === "popupContent")
                return true;
        return false;
    }

    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: Math.max(row.implicitWidth + hPadding * 2, Config.barHeight - 2)
    implicitHeight: Config.barHeight - 2
    radius: Theme.radius
    color: ma.pressed ? Theme.pressed : active ? activeColor : ma.containsMouse ? Theme.hover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
    }

    Rectangle {
        visible: root.indicator > 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.indicator === 2 ? 10 : 4
        height: 2
        radius: 1
        color: root.indicator === 2 ? Theme.accent : Theme.fg

        Behavior on width {
            NumberAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (!root.insidePopup())
                Popups.closeCurrent();
        }
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.scrolled(wheel)
    }

    Item {
        id: overlayItem
        anchors.fill: parent
    }
}
