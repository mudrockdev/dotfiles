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

    // Tüm içerik tek bir QML öğesinde: çalışma alanı önizlemesi bunun görüntüsünü alır
    // (pencerenin kök öğesi QML dışından oluşturulduğu için grabToImage ile alınamıyor).
    Item {
        id: content
        anchors.fill: parent

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
                    panelMenu.visible = false;
                    if (Editor.active)
                        Editor.finish();
                    else
                        Editor.start();
                }
            }
            MenuItem {
                visible: Editor.active
                text: "Cancel editing"
                icon: "edit-undo-symbolic"
                onTriggered: {
                    panelMenu.visible = false;
                    Editor.cancel();
                }
            }
            MenuItem {
                text: "Reload config"
                icon: "view-refresh-symbolic"
                onTriggered: {
                    panelMenu.visible = false;
                    Quickshell.reload(false);
                }
            }
        }

        // Sol: başlatıcı + uygulama listesi
        RowLayout {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Launcher {}
            AppList {}
        }

        // Düzenleme modunda sağda: sarkan çapa ayarları
        PopupWindow {
            id: anchorMenu

            readonly property string currentScreen: Settings.anchorScreen !== "" && Quickshell.screens.some(s => s.name === Settings.anchorScreen) ? Settings.anchorScreen : (Quickshell.screens[0]?.name ?? "")

            // Panelin altından biraz boşlukla, sağ kenara hizalı (paneli örtmesin)
            anchor.item: content
            anchor.edges: Edges.Bottom | Edges.Right
            anchor.gravity: Edges.Bottom | Edges.Left
            anchor.margins.right: 4
            anchor.adjustment: PopupAdjustment.SlideX
            visible: Editor.active
            color: "transparent"
            implicitWidth: anchorBox.implicitWidth
            implicitHeight: anchorBox.implicitHeight + 8

            Rectangle {
                id: anchorBox
                y: 8
                implicitWidth: Math.max(240, anchorCol.implicitWidth + 12)
                implicitHeight: anchorCol.implicitHeight + 12
                color: Theme.popupBg
                radius: Theme.radiusM
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    id: anchorCol
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 0

                    Toggle {
                        text: "Hanging anchor"
                        icon: Qt.resolvedUrl("assets/al-anchor.svg")
                        colorizeIcon: false
                        subtitle: Theme.azur ? "Hangs from the theme button; drag it around" : "Azur Lane theme only"
                        enabled: Theme.azur
                        opacity: enabled ? 1 : 0.5
                        checked: Settings.hangingAnchor
                        onToggled: Settings.hangingAnchor = !Settings.hangingAnchor
                    }
                    Toggle {
                        visible: Theme.azur && Settings.hangingAnchor
                        text: "Idle swinging"
                        icon: "weather-windy-symbolic"
                        bold: false
                        subtitle: "Sways gently in a breeze"
                        checked: Settings.anchorSwing
                        onToggled: Settings.anchorSwing = !Settings.anchorSwing
                    }
                    SectionTitle {
                        visible: Theme.azur && Settings.hangingAnchor
                        text: "Monitor"
                    }
                    Repeater {
                        model: Theme.azur && Settings.hangingAnchor ? Quickshell.screens : []

                        delegate: MenuItem {
                            required property var modelData
                            text: modelData.name
                            secondary: modelData.width + "×" + modelData.height
                            icon: "video-display-symbolic"
                            checked: modelData.name === anchorMenu.currentScreen
                            onTriggered: Settings.anchorScreen = modelData.name
                        }
                    }
                }
            }
        }

        // Orta: saat
        Clock {
            id: clock
            anchors.centerIn: parent
        }

        // Düzenleme modunda saatin altında: İptal / Bitti.
        // Odak yakalamaz; dışarı tıklamak (ör. başlatıcı sürüklemek) onu kapatmaz.
        PopupWindow {
            id: editBar

            anchor.item: clock
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.adjustment: PopupAdjustment.Slide
            visible: Editor.active
            color: "transparent"
            implicitWidth: editBox.implicitWidth
            implicitHeight: editBox.implicitHeight + 4

            Rectangle {
                id: editBox
                y: 4
                implicitWidth: editRow.implicitWidth + 16
                implicitHeight: editRow.implicitHeight + 12
                color: Theme.popupBg
                radius: Theme.radiusM
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    id: editRow
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        Layout.leftMargin: 4
                        icon: "document-edit-symbolic"
                        color: Theme.fgDim
                    }
                    Label {
                        text: "Editing panel"
                        color: Theme.fgDim
                        Layout.rightMargin: 4
                    }
                    TextButton {
                        text: "Cancel"
                        onClicked: Editor.cancel()
                    }
                    TextButton {
                        text: "Done"
                        primary: true
                        onClicked: Editor.finish()
                    }
                }
            }
        }

        // Sağ: sistem monitörü, çalışma alanları, klavye, tepsi, medya, tema, ses, bluetooth, ağ, güç
        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            SysMonitor {
                Layout.rightMargin: 4
            }
            Workspaces {
                barScreen: bar.screen
                panelItem: content
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
}
