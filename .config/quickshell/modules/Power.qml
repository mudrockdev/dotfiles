import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

BarButton {
    id: root

    Icon {
        icon: "system-shutdown-symbolic"
    }

    onClicked: popup.toggle()

    function run(cmd) {
        popup.visible = false;
        Quickshell.execDetached(Config.powerCommands[cmd]);
    }

    Popup {
        id: popup
        anchorItem: root
        minWidth: 200

        MenuItem {
            text: "Lock"
            icon: "system-lock-screen-symbolic"
            onTriggered: root.run("lock")
        }
        MenuItem {
            text: "Suspend"
            icon: "media-playback-pause-symbolic"
            onTriggered: root.run("suspend")
        }
        MenuItem {
            text: "Log out"
            icon: "system-log-out-symbolic"
            onTriggered: root.run("logout")
        }
        Separator {}
        MenuItem {
            text: "Restart"
            icon: "system-reboot-symbolic"
            onTriggered: root.run("reboot")
        }
        MenuItem {
            text: "Shut down"
            icon: "system-shutdown-symbolic"
            onTriggered: root.run("shutdown")
        }
    }
}
