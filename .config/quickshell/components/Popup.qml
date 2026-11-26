import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Panel butonunun altında açılan menü. Dışarı tıklayınca kapanır (grabFocus).
PopupWindow {
    id: root

    property Item anchorItem
    property int padding: 6
    property int minWidth: 220
    property int maxWidth: 380
    property alias spacing: layout.spacing
    default property alias content: layout.data

    function toggle() {
        if (Popups.justClosed === root) {
            // bu basışta zaten kapandı; yeniden açma
            Popups.justClosed = null;
            return;
        }
        visible = !visible;
    }

    onVisibleChanged: {
        if (visible) {
            if (Popups.current && Popups.current !== root)
                Popups.current.visible = false;
            Popups.current = root;
        } else if (Popups.current === root) {
            Popups.current = null;
        }
    }

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.FlipY
    grabFocus: true
    visible: false
    color: "transparent"

    implicitWidth: Math.min(maxWidth, Math.max(minWidth, layout.implicitWidth + padding * 2))
    implicitHeight: layout.implicitHeight + padding * 2 + 4

    Rectangle {
        objectName: "popupContent"
        anchors.fill: parent
        anchors.topMargin: 4
        color: Theme.popupBg
        radius: Theme.radiusM
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: 0
        }
    }
}
