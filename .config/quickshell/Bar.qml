import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
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

    // Boş alana tıklama: sol = açık popup'ı kapat, sağ = panel menüsü
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: Popups.closeCurrent()
        onClicked: mouse => {
            if (mouse.button !== Qt.RightButton)
                return;
            Popups.justClosed = null;
            menuAnchor.x = mouse.x;
            panelMenu.visible = true;
        }
    }

    // Panel menüsü tıklanan noktanın altında açılsın
    Item {
        id: menuAnchor
        width: 1
        height: parent.height
    }

    Popup {
        id: panelMenu
        anchorItem: menuAnchor
        minWidth: 200

        MenuItem {
            text: Editor.active ? "Finish editing" : "Edit panel"
            icon: Editor.active ? "object-select-symbolic" : "document-edit-symbolic"
            onTriggered: {
                Editor.active = !Editor.active;
                panelMenu.visible = false;
            }
        }
    }

    // Sol: başlatıcı + uygulama listesi
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Launcher {}
        AppList {}
        // Düzenleme modundayken bitirme düğmesi
        BarButton {
            visible: Editor.active
            Layout.leftMargin: 4
            active: true
            activeColor: Theme.accent
            Label {
                text: "Done"
                color: "white"
                font.bold: true
            }
            onClicked: Editor.active = false
        }
    }

    // Orta: saat
    Clock {
        anchors.centerIn: parent
    }

    // Sağ: sistem monitörü, çalışma alanları, klavye, tepsi, medya, tema, ses, bluetooth, ağ, güç
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
        Tray {}
        Media {}
        ThemeSelector {}
        Audio {}
        BluetoothButton {}
        NetworkButton {}
        Power {}
    }
}
