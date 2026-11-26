import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules

PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Config.barHeight
    color: Theme.panelBg

    WlrLayershell.namespace: "quickshell-panel"
    WlrLayershell.layer: WlrLayer.Top

    // Sol: başlatıcı + uygulama listesi
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Launcher {}
        AppList {}
    }

    // Orta: saat
    Clock {
        anchors.centerIn: parent
    }

    // Sağ: sistem monitörü, çalışma alanları, klavye, tepsi, medya, ses, bluetooth, ağ, güç
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        SysMonitor {
            Layout.rightMargin: 4
        }
        Workspaces {
            barScreen: bar.screen
            Layout.rightMargin: 4
        }
        Keyboard {}
        Tray {
            panel: bar
        }
        Media {}
        Audio {}
        BluetoothButton {}
        NetworkButton {}
        Power {}
    }
}
