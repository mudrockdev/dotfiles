pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Eksik bağımlılık uyarısı. Her şey kuruluysa hiç görünmez.
BarButton {
    id: root

    visible: Deps.missing.length > 0

    Icon {
        icon: "dialog-warning-symbolic"
        color: Theme.temp
    }

    onClicked: {
        Deps.check();
        popup.toggle();
    }

    Popup {
        id: popup
        anchorItem: root
        minWidth: 320
        maxWidth: 420

        SectionTitle {
            text: "Eksik bağımlılıklar"
        }

        Repeater {
            model: Deps.missing

            delegate: MenuItem {
                required property var modelData
                icon: "dialog-warning-symbolic"
                text: modelData.name
                subtitle: modelData.why
                secondary: modelData.pkg
                enabled: false
                opacity: 1
            }
        }

        Separator {}

        MenuItem {
            text: "Kurulum komutunu kopyala"
            subtitle: Deps.installCommand
            icon: "edit-copy-symbolic"
            onTriggered: {
                Quickshell.clipboardText = Deps.installCommand;
                popup.visible = false;
            }
        }
        MenuItem {
            text: "Yeniden denetle"
            icon: "view-refresh-symbolic"
            onTriggered: Deps.check()
        }
    }
}
