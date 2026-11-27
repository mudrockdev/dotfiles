pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.WindowManager
import qs
import qs.components

// ext-workspace-v1 üzerinden COSMIC çalışma alanları.
// Üzerine gelince çalışma alanının küçük önizlemesi (pencere düzeni + görüntüleri) açılır.
RowLayout {
    id: root

    required property ShellScreen barScreen
    // Önizlemede gösterilecek panel içeriği (Bar.qml'deki kapsayıcı öğe)
    property Item panelItem: null
    readonly property var projection: barScreen ? WindowManager.screenProjection(barScreen) : null
    readonly property var sets: (projection?.windowsets ?? WindowManager.windowsets).filter(w => w.shouldDisplay)

    // Önizlemesi gösterilen düğme (yoksa null)
    property var hoverBtn: null

    spacing: 2

    function cycle(dir) {
        const s = root.sets;
        if (s.length === 0)
            return;
        const i = s.findIndex(w => w.active);
        const next = s[Math.max(0, Math.min(s.length - 1, i + dir))];
        if (next && next.canActivate)
            next.activate();
    }

    function windowsOn(ws) {
        const name = root.barScreen?.name ?? "";
        return Toplevels.list.filter(t => Toplevels.onWorkspace(t, ws, name));
    }

    Repeater {
        model: root.sets

        delegate: BarButton {
            id: ws
            required property var modelData
            required property int index

            implicitWidth: Math.max(20, wsLabel.implicitWidth + 12)
            active: modelData.active
            activeColor: Theme.accent
            border.width: modelData.urgent && !modelData.active ? 1 : 0
            border.color: Theme.accent

            Label {
                id: wsLabel
                text: ws.modelData.name || (ws.index + 1)
                font.bold: ws.modelData.active
                color: ws.modelData.active ? "white" : Theme.fg
            }

            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    if (preview.visible) {
                        root.hoverBtn = ws; // açıkken komşuya geçiş: hemen değiştir
                    } else {
                        root.hoverBtn = ws;
                        showTimer.restart();
                    }
                } else if (root.hoverBtn === ws) {
                    showTimer.stop();
                    hideTimer.restart();
                }
            }

            onClicked: if (modelData.canActivate)
                modelData.activate()
            onScrolled: wheel => root.cycle(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }

    Timer {
        id: showTimer
        interval: 350
        onTriggered: preview.visible = root.hoverBtn !== null
    }
    Timer {
        id: hideTimer
        interval: 150
        onTriggered: {
            preview.visible = false;
            root.hoverBtn = null;
        }
    }

    // Başka bir popup açılınca önizleme kapansın
    Connections {
        target: Popups
        function onCurrentChanged() {
            if (Popups.current)
                hideTimer.restart();
        }
    }

    PopupWindow {
        id: preview

        readonly property var wsData: root.hoverBtn?.modelData ?? null
        readonly property var windows: wsData ? root.windowsOn(wsData).filter(t => !t.minimized && t.geometry) : []
        readonly property real screenW: root.barScreen?.width ?? 1920
        readonly property real screenH: root.barScreen?.height ?? 1080
        readonly property real scale: 420 / screenW
        readonly property var wallpaper: Wallpaper.forScreen(root.barScreen?.name ?? "")

        // Panelin kendisinin görüntüsü (grabToImage sonucu; url'si sonuç nesnesi yaşadıkça geçerli)
        property var panelGrab: null

        function grabPanel() {
            const p = root.panelItem;
            if (!p)
                return;
            const w = Math.round(p.width * preview.scale * 2);
            const h = Math.max(2, Math.round(p.height * preview.scale * 2));
            p.grabToImage(r => preview.panelGrab = r, Qt.size(w, h));
        }

        // Açılınca / çalışma alanı değişince pencere görüntülerini yakala
        function refresh() {
            if (!visible)
                return;
            for (const w of windows)
                Toplevels.capture(w);
        }
        onVisibleChanged: {
            if (visible) {
                grabPanel();
                Wallpaper.refreshAura(root.barScreen?.name ?? "", Math.round(screenW * scale * 2));
            }
            refresh();
        }
        onWsDataChanged: {
            refresh();
            if (visible)
                anchor.updateAnchor();
        }

        anchor.item: root.hoverBtn ?? root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.FlipY
        visible: false
        color: "transparent"

        implicitWidth: box.implicitWidth
        implicitHeight: box.implicitHeight + 4

        Rectangle {
            id: box
            y: 4
            implicitWidth: col.implicitWidth + 16
            implicitHeight: col.implicitHeight + 16
            color: Theme.popupBg
            radius: Theme.radiusM
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                id: col
                anchors.centerIn: parent
                spacing: 6

                Label {
                    text: {
                        const n = preview.windows.length;
                        const name = preview.wsData?.name ?? "";
                        return "Workspace " + name + "  ·  " + (n === 0 ? "empty" : n === 1 ? "1 window" : n + " windows");
                    }
                    color: Theme.fgDim
                    font.bold: true
                }

                // Küçük masaüstü
                Rectangle {
                    implicitWidth: Math.round(preview.screenW * preview.scale)
                    implicitHeight: Math.round(preview.screenH * preview.scale)
                    radius: Theme.radiusS
                    color: preview.wallpaper.color
                    border.color: Theme.separator
                    border.width: 1
                    clip: true

                    // Duvar kağıdı
                    Image {
                        anchors.fill: parent
                        source: preview.wallpaper.path
                        sourceSize.width: 600
                        fillMode: preview.wallpaper.mode === "stretch" ? Image.Stretch : preview.wallpaper.mode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        cache: false
                        retainWhileLoading: true
                    }

                    // Panel: arka plan rengi pencereye ait olduğundan ayrıca çizilir, üstüne panelin görüntüsü
                    Rectangle {
                        width: parent.width
                        height: Math.max(2, Config.barHeight * preview.scale)
                        color: Theme.panelBg

                        Image {
                            anchors.fill: parent
                            source: preview.panelGrab?.url ?? ""
                            smooth: true
                            mipmap: true
                        }
                    }

                    Repeater {
                        // Yığın sırası: en son odaklanan en üstte (stack büyük = üstte),
                        // geçmişi bilinmeyenler en altta, odaktaki her zaman en üstte
                        model: preview.windows.slice().sort((a, b) => (a.activated - b.activated) || ((a.stack ?? 0) - (b.stack ?? 0)) || (a.id - b.id))

                        delegate: Rectangle {
                            id: win
                            required property var modelData
                            readonly property var g: modelData.geometry
                            readonly property string thumb: Toplevels.previews[modelData.id] ?? ""

                            x: g.x * preview.scale
                            y: g.y * preview.scale
                            width: Math.max(8, g.w * preview.scale)
                            height: Math.max(8, g.h * preview.scale)
                            radius: 3
                            color: Theme.popupBg
                            border.width: 1
                            border.color: modelData.activated ? Theme.accent : Theme.border
                            clip: true

                            Image {
                                id: img
                                anchors.fill: parent
                                anchors.margins: 1
                                source: win.thumb
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                visible: status === Image.Ready
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !img.visible
                                size: Math.min(24, parent.height - 4)
                                colorize: false
                                icon: DesktopEntries.heuristicLookup(win.modelData.appId)?.icon ?? win.modelData.appId
                                fallback: "application-x-executable"
                            }
                        }
                    }
                }
            }
        }
    }
}
