pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.components

// Panel teması seçici (Varsayılan / Azur Lane).
BarButton {
    id: root

    Icon {
        icon: Qt.resolvedUrl("../assets/al-anchor.svg")
        colorize: false
        size: 18
    }

    onClicked: popup.toggle()

    // Sarkan çapanın zinciri bu düğmeden başlar: ekrandaki merkezini paylaş
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property real centerX: {
        // düzen değişince yeniden hesapla
        root.x;
        root.width;
        root.parent?.x;
        root.parent?.width;
        root.QsWindow.window?.width;
        return root.mapToItem(null, root.width / 2, 0).x;
    }
    function publish() {
        if (root.screenName === "")
            return;
        const m = Object.assign({}, Theme.selectorX);
        m[root.screenName] = root.centerX;
        Theme.selectorX = m;
    }
    onCenterXChanged: publish()
    onScreenNameChanged: publish()
    Component.onCompleted: publish()

    Popup {
        id: popup
        anchorItem: root
        minWidth: 180

        SectionTitle {
            text: "Theme"
        }
        Repeater {
            model: Theme.themes
            delegate: MenuItem {
                required property var modelData
                text: modelData.name
                checked: Theme.name === modelData.id
                icon: modelData.icon
                colorizeIcon: modelData.colorize
                onTriggered: {
                    Settings.theme = modelData.id;
                    popup.visible = false;
                }
            }
        }
    }
}
