pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components

// StatusNotifier tepsisi (COSMIC Status Area).
// Menüler Qt'nin QMenu'su yerine kendi popup'ımızla çizilir; böylece bir ikondan
// diğerine tek sağ tıkla geçilebilir (QMenu dış tıklamayı yutuyordu).
RowLayout {
    id: root

    spacing: 0

    // Tray ikonuna ait pencereler (ör. "vesktop_status_icon_1" -> dev.vencord.Vesktop, "steam" -> steam)
    function windowsFor(item) {
        const id = (item.id || "").toLowerCase().replace(/_status_icon(_\d+)?$/, "");
        if (id === "")
            return [];
        return Toplevels.list.filter(t => {
            const a = (t.appId || "").toLowerCase();
            return a !== "" && (a === id || a.endsWith("." + id) || id.endsWith("." + a));
        });
    }

    function openMenu(btn, item) {
        menu.stack = [];
        menu.trayItem = item;
        menu.anchorItem = btn;
        menu.visible = true;
    }

    Repeater {
        model: SystemTray.items

        delegate: BarButton {
            id: btn
            required property SystemTrayItem modelData

            hPadding: 4

            // Sol tıktan sonra uygulama kendi penceresini öne getiremediyse
            // (Wayland'de odak çalma yasak / AppIndicator'larda Activate yok) yardım et.
            Timer {
                id: followUp
                interval: 500
                onTriggered: {
                    const wins = root.windowsFor(btn.modelData);
                    if (wins.some(w => w.activated))
                        return;
                    if (wins.length > 0)
                        Toplevels.activate(wins.find(w => !w.minimized) ?? wins[0]);
                    else if (btn.modelData.hasMenu)
                        root.openMenu(btn, btn.modelData);
                }
            }

            Icon {
                icon: btn.modelData.icon
                colorize: false
                size: 16
            }

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (modelData.hasMenu)
                        root.openMenu(btn, modelData);
                    return;
                }
                // sol/orta tık bu basışta bir popup kapattıysa yalnızca onu kapatsın
                const closedPopup = Popups.justClosed !== null;
                Popups.justClosed = null;
                if (closedPopup)
                    return;
                if (mouse.button === Qt.MiddleButton)
                    modelData.secondaryActivate();
                else if (modelData.onlyMenu && modelData.hasMenu)
                    root.openMenu(btn, modelData);
                else {
                    modelData.activate();
                    followUp.restart();
                }
            }
            onScrolled: wheel => modelData.scroll(wheel.angleDelta.y, false)
        }
    }

    Popup {
        id: menu

        property var trayItem: null
        // açılan alt menüler (en sondaki gösterilir)
        property var stack: []

        minWidth: 200
        maxWidth: 420
        padding: 6
        spacing: 0

        onVisibleChanged: if (!visible)
            stack = []

        QsMenuOpener {
            id: opener
            menu: menu.stack.length > 0 ? menu.stack[menu.stack.length - 1] : (menu.trayItem?.menu ?? null)
        }

        // alt menüdeyken geri
        MenuItem {
            visible: menu.stack.length > 0
            text: "Geri"
            icon: "go-previous-symbolic"
            onTriggered: menu.stack = menu.stack.slice(0, -1)
        }
        Separator {
            visible: menu.stack.length > 0
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: entry

                required property QsMenuEntry modelData
                readonly property bool sep: modelData.isSeparator

                Layout.fillWidth: true
                implicitHeight: sep ? 9 : 30
                implicitWidth: sep ? 0 : row.implicitWidth + 16

                Rectangle {
                    visible: entry.sep
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Theme.separator
                }

                Rectangle {
                    visible: !entry.sep
                    anchors.fill: parent
                    radius: Theme.radius
                    opacity: entry.modelData.enabled ? 1 : 0.45
                    color: entryMa.pressed ? Theme.pressed : entryMa.containsMouse ? Theme.hover : "transparent"

                    RowLayout {
                        id: row
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // onay kutusu / radyo düğmesi
                        Item {
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None
                            implicitWidth: 16
                            implicitHeight: 16

                            Rectangle {
                                anchors.fill: parent
                                radius: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? 8 : 3
                                color: entry.modelData.checkState === Qt.Checked ? Theme.accent : "transparent"
                                border.width: entry.modelData.checkState === Qt.Checked ? 0 : 1
                                border.color: Theme.fgDim
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: entry.modelData.checkState === Qt.Checked
                                icon: "object-select-symbolic"
                                size: 12
                                color: "white"
                            }
                        }

                        Icon {
                            visible: entry.modelData.icon !== ""
                            icon: entry.modelData.icon
                            colorize: false
                            size: 16
                        }

                        Label {
                            Layout.fillWidth: true
                            text: entry.modelData.text
                        }

                        Icon {
                            visible: entry.modelData.hasChildren
                            icon: "go-next-symbolic"
                            size: 12
                        }
                    }

                    MouseArea {
                        id: entryMa
                        anchors.fill: parent
                        enabled: entry.modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                menu.stack = menu.stack.concat([entry.modelData]);
                            } else {
                                entry.modelData.triggered();
                                menu.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
