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
