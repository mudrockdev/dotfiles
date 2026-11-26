import QtQuick
import Quickshell
import qs
import qs.components

// COSMIC App Library düğmesi.
BarButton {
    Icon {
        icon: "view-app-grid-symbolic"
        fallback: "start-here-symbolic"
    }
    onClicked: Quickshell.execDetached(Config.launcherCommand)
}
