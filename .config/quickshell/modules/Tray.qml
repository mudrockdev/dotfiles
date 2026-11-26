pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components

// StatusNotifier tepsisi (COSMIC Status Area).
RowLayout {
    id: root

    required property var panel

    spacing: 0

    Repeater {
        model: SystemTray.items

        delegate: BarButton {
            id: item
            required property SystemTrayItem modelData

            hPadding: 4

            Icon {
                icon: item.modelData.icon
                colorize: false
                size: 16
            }

            onClicked: mouse => {
                const showMenu = () => {
                    const p = item.mapToItem(null, 0, item.height + 4);
                    modelData.display(root.panel, p.x, p.y);
                };
                if (mouse.button === Qt.LeftButton) {
                    if (modelData.onlyMenu && modelData.hasMenu)
                        showMenu();
                    else
                        modelData.activate();
                } else if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (modelData.hasMenu) {
                    showMenu();
                }
            }
            onScrolled: wheel => modelData.scroll(wheel.angleDelta.y, false)
        }
    }
}
