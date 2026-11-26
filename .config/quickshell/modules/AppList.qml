pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
                key: f
            }))

    // favorilerde olmayan açık uygulamalar
    readonly property var otherItems: {
        const out = [];
        const all = root.pinnedItems.slice();
        for (const tl of ToplevelManager.toplevels.values) {
            if (!tl.appId)
                continue;
            if (all.some(o => root.matches(tl, o.key, root.entryFor(o.key))))
                continue;
            const item = {
                key: tl.appId
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
            readonly property var entry: root.entryFor(key)
            readonly property var windows: ToplevelManager.toplevels.values.filter(t => root.matches(t, btn.key, btn.entry))
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
                if (mouse.button === Qt.MiddleButton) {
                    root.launch(key, entry);
                } else if (mouse.button === Qt.RightButton) {
                    menu.target = btn;
                    menu.visible = true;
                } else if (windows.length === 0) {
                    root.launch(key, entry);
                } else if (windows.length === 1) {
                    const w = windows[0];
                    if (w.activated)
                        w.minimized = true;
                    else
                        w.activate();
                } else {
                    // birden fazla pencere: sıradakine geç
                    const i = windows.findIndex(w => w.activated);
                    windows[(i + 1) % windows.length].activate();
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
                    modelData.activate();
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

        MenuItem {
            visible: (menu.target?.windows.length ?? 0) > 0
            text: menu.target?.windows.length > 1 ? "Tümünü kapat" : "Kapat"
            icon: "window-close-symbolic"
            onTriggered: {
                for (const w of menu.target.windows)
                    w.close();
                menu.visible = false;
            }
        }
    }
}
