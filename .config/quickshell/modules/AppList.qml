pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// COSMIC App List: sabitlenmiş favoriler + açık olan diğer uygulamalar.
RowLayout {
    id: root

    spacing: 0

    function norm(s) {
        return (s || "").toLowerCase();
    }

    function entryFor(id) {
        DesktopEntries.applications.values; // yeni .desktop dosyalarında yeniden hesapla
        return DesktopEntries.heuristicLookup(id);
    }

    function matches(tl, key, entry) {
        const a = norm(tl.appId);
        if (a === "")
            return false;
        if (a === norm(key))
            return true;
        if (!entry)
            return false;
        if (a === norm(entry.id))
            return true;
        const e2 = DesktopEntries.heuristicLookup(tl.appId);
        return e2 !== null && e2.id === entry.id;
    }

    function launch(key, entry) {
        if (entry)
            entry.execute();
        else
            Quickshell.execDetached([key]);
    }

    readonly property var pinnedItems: Config.favorites.map(f => ({
                key: f,
                pinned: true
            }))

    // favorilerde olmayan açık uygulamalar
    readonly property var otherItems: {
        const out = [];
        const all = root.pinnedItems.slice();
        for (const tl of Toplevels.list) {
            if (!tl.appId)
                continue;
            if (all.some(o => root.matches(tl, o.key, root.entryFor(o.key))))
                continue;
            const item = {
                key: tl.appId,
                pinned: false
            };
            all.push(item);
            out.push(item);
        }
        return out;
    }

    Repeater {
        model: ScriptModel {
            values: root.pinnedItems
            objectProp: "key"
        }
        delegate: appButton
    }

    Rectangle {
        visible: root.otherItems.length > 0
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        implicitWidth: 1
        implicitHeight: Config.barHeight - 10
        color: Theme.fgDim
        opacity: 0.6
    }

    Repeater {
        model: ScriptModel {
            values: root.otherItems
            objectProp: "key"
        }
        delegate: appButton
    }

    Component {
        id: appButton

        BarButton {
            id: btn

            required property var modelData
            readonly property string key: modelData.key
            readonly property bool pinned: modelData.pinned
            readonly property var entry: root.entryFor(key)
            readonly property var windows: Toplevels.list.filter(t => root.matches(t, btn.key, btn.entry))
            readonly property bool focused: windows.some(w => w.activated)

            hPadding: 3
            indicator: focused ? 2 : windows.length > 0 ? 1 : 0

            Icon {
                icon: btn.entry?.icon ?? btn.key
                fallback: "application-x-executable"
                colorize: false
                size: Config.barHeight - 6
            }

            onClicked: mouse => {
                // Bu basış açık bir popup'ı kapattıysa tıklama sadece onu kapatır;
                // sağ tık ise her zaman (yeniden) bağlam menüsünü açar.
                const closedPopup = Popups.justClosed !== null;
                Popups.justClosed = null;
                if (mouse.button === Qt.RightButton) {
                    menu.target = btn;
                    menu.visible = true;
                } else if (closedPopup) {
                    return;
                } else if (mouse.button === Qt.MiddleButton) {
                    root.launch(key, entry);
                } else if (windows.length === 0) {
                    root.launch(key, entry);
                } else if (windows.length === 1) {
                    // COSMIC gibi: odaktaysa küçült, değilse (küçültülmüş olsa bile) geri getir
                    const w = windows[0];
                    if (w.activated)
                        Toplevels.minimize(w);
                    else
                        Toplevels.activate(w);
                } else {
                    // birden fazla pencere: önizlemeli pencere seçici
                    picker.target = btn;
                    for (const w of windows)
                        Toplevels.capture(w);
                    picker.visible = true;
                }
            }
        }
    }

    // Sağ tık menüsü (tüm uygulamalar için tek popup)
    Popup {
        id: menu

        property var target: null

        anchorItem: target ?? root

        SectionTitle {
            text: menu.target?.entry?.name ?? menu.target?.key ?? ""
        }

        Repeater {
            model: menu.target?.windows ?? []

            delegate: MenuItem {
                required property var modelData
                text: modelData.title || modelData.appId
                checked: modelData.activated
                onTriggered: {
                    Toplevels.activate(modelData);
                    menu.visible = false;
                }
            }
        }

        Separator {
            visible: (menu.target?.windows.length ?? 0) > 0
        }

        MenuItem {
            text: "Yeni pencere"
            icon: "window-new-symbolic"
            onTriggered: {
                root.launch(menu.target.key, menu.target.entry);
                menu.visible = false;
            }
        }

        Repeater {
            model: menu.target?.entry?.actions ?? []

            delegate: MenuItem {
                required property var modelData
                text: modelData.name
                onTriggered: {
                    modelData.execute();
                    menu.visible = false;
                }
            }
        }

        Separator {}

        MenuItem {
            visible: menu.target?.pinned ?? false
            text: "Başlatıcılardan kaldır"
            icon: "view-pin-symbolic"
            onTriggered: {
                const key = menu.target.key;
                menu.visible = false;
                Config.unpin(key);
            }
        }

        MenuItem {
            visible: !(menu.target?.pinned ?? true)
            text: "Başlatıcılara sabitle"
            icon: "view-pin-symbolic"
            onTriggered: {
                const key = menu.target.key;
                menu.visible = false;
                Config.pin(key);
            }
        }

        MenuItem {
            visible: (menu.target?.windows.length ?? 0) > 0
            text: menu.target?.windows.length > 1 ? "Tümünü kapat" : "Kapat"
            icon: "window-close-symbolic"
            onTriggered: {
                for (const w of menu.target.windows)
                    Toplevels.close(w);
                menu.visible = false;
            }
        }
    }

    // Birden fazla pencere varken sol tık: önizlemeli pencere seçici (COSMIC gibi)
    Popup {
        id: picker

        property var target: null

        anchorItem: target ?? root
        maxWidth: 1800

        // Son pencere de kapanınca seçiciyi kapat
        readonly property int windowCount: target?.windows.length ?? 0
        onWindowCountChanged: if (visible && windowCount === 0)
            visible = false
        minWidth: 0
        padding: 8

        RowLayout {
            spacing: 6

            Repeater {
                model: picker.target?.windows ?? []

                delegate: Rectangle {
                    id: card

                    required property var modelData
                    readonly property string preview: Toplevels.previews[modelData.id] ?? ""

                    implicitWidth: 220
                    implicitHeight: 160
                    radius: 8
                    color: cardMa.pressed ? Theme.pressed : cardMa.containsMouse ? Theme.hover : "transparent"
                    border.width: modelData.activated ? 1 : 0
                    border.color: Theme.accent

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Image {
                                id: thumb
                                anchors.fill: parent
                                source: card.preview
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                visible: status === Image.Ready
                                opacity: card.modelData.minimized ? 0.6 : 1
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !thumb.visible
                                size: 48
                                colorize: false
                                icon: picker.target?.entry?.icon ?? card.modelData.appId
                                fallback: "application-x-executable"
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: card.modelData.title || card.modelData.appId
                        }
                    }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                Toplevels.close(card.modelData);
                            } else {
                                Toplevels.activate(card.modelData);
                                picker.visible = false;
                            }
                        }
                    }

                    HoverHandler {
                        id: cardHover
                    }

                    // Kapat düğmesi (üzerine gelince görünür)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 24
                        height: 24
                        radius: 12
                        visible: cardHover.hovered
                        color: closeMa.pressed ? Qt.darker(Theme.accent, 1.2) : closeMa.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.65)

                        Icon {
                            anchors.centerIn: parent
                            icon: "window-close-symbolic"
                            size: 14
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Toplevels.close(card.modelData)
                        }
                    }
                }
            }
        }
    }
}
