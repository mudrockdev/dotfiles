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

        // İmleç menüdeyken DeepSeek-chan bakışlarıyla takip eder. Menünün gerçek konumu
        // okunamıyor: bağlandığı öğenin altında ortalanmış varsayılır (Slide ile kenara yaslanır).
        HoverHandler {
            onPointChanged: {
                if (!hovered || !root.anchorItem)
                    return;
                const win = root.anchorItem.QsWindow.window;
                if (!win)
                    return;
                const a = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, root.anchorItem.height);
                const x0 = Math.max(0, Math.min(win.width - root.width, a.x - root.width / 2));
                DeepSeek.cursorAt(win.screen, x0 + point.position.x, a.y + 4 + point.position.y);
            }
            onHoveredChanged: if (!hovered)
                DeepSeek.cursorLeft()
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: 0
        }
    }
}
