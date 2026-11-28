import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Panelden zincirle sarkan Azur Lane çapası (yalnızca Azur Lane temasında, seçili ekranda).
// Zincir Verlet fiziğiyle simüle edilir: çapa tutulup çekilebilir, fırlatılabilir, sallanır.
// Pencere ekranı kaplar ama giriş maskesi yalnızca çapadır; altındaki pencereler tıklanabilir.
// Zincir paneldeki tema seçici düğmesinin altından başlar.
Scope {
    id: root

    readonly property bool enabled: Settings.hangingAnchor && Theme.azur
    readonly property string screenName: Settings.anchorScreen !== "" && Quickshell.screens.some(s => s.name === Settings.anchorScreen) ? Settings.anchorScreen : (Quickshell.screens[0]?.name ?? "")

    Variants {
        model: root.enabled ? Quickshell.screens.filter(s => s.name === root.screenName) : []

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            margins.top: Config.barHeight
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "quickshell-anchor"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Yalnızca çapa tıklanabilir
            mask: Region {
                item: grabArea
            }

            // ---------------- Fizik ----------------
            readonly property int links: 9
            readonly property real seg: 11
            readonly property real anchorSize: 64
            // Çapa görselinde zincirin takıldığı nokta (üstteki halka), görsele oranla
            readonly property real attachX: 0.495
            readonly property real attachY: 0.09
            readonly property real gravity: 1900
            readonly property real stepDt: 1 / 120

            // Zincir panelin tema seçici düğmesinden başlar
            readonly property real mountX: Theme.selectorX[win.modelData.name] ?? width * 0.8
            property var pts: []    // [{x, y}] — 0 bağlantı noktası, son nokta çapa
            property var prev: []
            property bool dragging: false
            property real dragX: 0
            property real dragY: 0
            property real acc: 0
            property int stillFrames: 0

            function reset() {
                const p = [], q = [];
                for (let i = 0; i <= links; i++) {
                    p.push({ x: mountX, y: i * seg });
                    q.push({ x: mountX, y: i * seg });
                }
                pts = p;
                prev = q;
                wake();
            }
            function wake() {
                stillFrames = 0;
                sim.running = true;
            }

            function step(dt) {
                const p = pts, q = prev, n = links;
                const w = width, h = height;
                // Verlet tümleme (0 sabit)
                for (let i = 1; i <= n; i++) {
                    const vx = (p[i].x - q[i].x) * 0.996;
                    const vy = (p[i].y - q[i].y) * 0.996;
                    q[i] = { x: p[i].x, y: p[i].y };
                    p[i] = { x: p[i].x + vx, y: p[i].y + vy + gravity * dt * dt };
                }
                p[0] = { x: mountX, y: 0 };
                if (dragging)
                    p[n] = { x: dragX, y: dragY };
                // Mesafe kısıtları; çapa ağır (az hareket eder), tutulunca sabit
                for (let it = 0; it < 14; it++) {
                    for (let i = 0; i < n; i++) {
                        const a = p[i], b = p[i + 1];
                        const wa = i === 0 ? 0 : 1;
                        const wb = i + 1 === n ? (dragging ? 0 : 0.35) : 1;
                        const sum = wa + wb;
                        if (sum === 0)
                            continue;
                        const dx = b.x - a.x, dy = b.y - a.y;
                        const d = Math.sqrt(dx * dx + dy * dy) || 0.0001;
                        const diff = (d - seg) / d;
                        p[i] = { x: a.x + dx * diff * wa / sum, y: a.y + dy * diff * wa / sum };
                        p[i + 1] = { x: b.x - dx * diff * wb / sum, y: b.y - dy * diff * wb / sum };
                    }
                }
                // Ekran kenarlarından sekme
                for (let i = 1; i <= n; i++) {
                    let { x, y } = p[i];
                    if (x < 4 || x > w - 4 || y < 0 || y > h - 4) {
                        const vx = x - q[i].x, vy = y - q[i].y;
                        if (x < 4) { x = 4; q[i] = { x: x + vx * 0.5, y: q[i].y }; }
                        if (x > w - 4) { x = w - 4; q[i] = { x: x + vx * 0.5, y: q[i].y }; }
                        if (y < 0) { y = 0; q[i] = { x: q[i].x, y: y + vy * 0.5 }; }
                        if (y > h - 4) { y = h - 4; q[i] = { x: q[i].x, y: y + vy * 0.5 }; }
                        p[i] = { x: x, y: y };
                    }
                }
            }

            FrameAnimation {
                id: sim
                running: false
                onTriggered: {
                    if (win.pts.length !== win.links + 1)
                        return;
                    win.acc = Math.min(win.acc + frameTime, 0.1);
                    while (win.acc >= win.stepDt) {
                        win.step(win.stepDt);
                        win.acc -= win.stepDt;
                    }
                    // Hareket bitince uyu (CPU kullanmasın)
                    let moving = win.dragging;
                    for (let i = 1; i <= win.links && !moving; i++)
                        if (Math.abs(win.pts[i].x - win.prev[i].x) + Math.abs(win.pts[i].y - win.prev[i].y) > 0.03)
                            moving = true;
                    win.stillFrames = moving ? 0 : win.stillFrames + 1;
                    win.pts = win.pts.slice(); // bağlamaları güncelle
                    if (win.stillFrames > 45)
                        running = false;
                }
            }

            Component.onCompleted: reset()
            onWidthChanged: wake()
            onHeightChanged: wake()
            onMountXChanged: wake()

            // ---------------- Çizim ----------------

            // Bağlantı halkası
            Rectangle {
                x: win.mountX - 5
                y: -3
                width: 10
                height: 8
                radius: 4
                color: "#2b3f73"
                border.color: "#c9d6f0"
                border.width: 1.5
            }

            // Zincir halkaları: dönüşümlü düz / yan halkalar
            Repeater {
                model: win.pts.length > 0 ? win.links : 0

                delegate: Rectangle {
                    required property int index
                    readonly property var a: win.pts[index]
                    readonly property var b: win.pts[index + 1]
                    readonly property real len: Math.sqrt((b.x - a.x) ** 2 + (b.y - a.y) ** 2)
                    readonly property bool flat: index % 2 === 0

                    width: len + 6
                    height: flat ? 7 : 3
                    x: (a.x + b.x) / 2 - width / 2
                    y: (a.y + b.y) / 2 - height / 2
                    rotation: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI
                    radius: height / 2
                    color: flat ? "transparent" : "#c9d6f0"
                    border.color: "#c9d6f0"
                    border.width: flat ? 2 : 0
                    antialiasing: true
                }
            }

            // Çapa
            Item {
                id: anchorItem
                readonly property var p: win.pts[win.links] ?? { x: win.mountX, y: win.links * win.seg }
                readonly property var q: win.pts[win.links - 1] ?? { x: win.mountX, y: 0 }
                readonly property real angle: -Math.atan2(p.x - q.x, p.y - q.y) * 180 / Math.PI

                x: p.x - win.attachX * win.anchorSize
                y: p.y - win.attachY * win.anchorSize
                width: win.anchorSize
                height: win.anchorSize
                transform: Rotation {
                    origin.x: win.attachX * win.anchorSize
                    origin.y: win.attachY * win.anchorSize
                    angle: anchorItem.angle
                }

                Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("assets/al-anchor.svg")
                    sourceSize.width: win.anchorSize * 2
                    sourceSize.height: win.anchorSize * 2
                    smooth: true
                    mipmap: true
                }
            }

            // Tutma alanı: dönmüş çapanın ortasını kaplayan kare (maske de bu)
            Item {
                id: grabArea
                readonly property real r: win.anchorSize * (0.5 - win.attachY)
                readonly property real rad: anchorItem.angle * Math.PI / 180
                readonly property real cx: anchorItem.p.x - Math.sin(rad) * r
                readonly property real cy: anchorItem.p.y + Math.cos(rad) * r
                readonly property real size: win.anchorSize * 0.95

                x: cx - size / 2
                y: cy - size / 2
                width: size
                height: size

                MouseArea {
                    anchors.fill: parent
                    cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real offX: 0
                    property real offY: 0
                    onPressed: mouse => {
                        const m = mapToItem(win.contentItem, mouse.x, mouse.y);
                        offX = anchorItem.p.x - m.x;
                        offY = anchorItem.p.y - m.y;
                        win.dragX = anchorItem.p.x;
                        win.dragY = anchorItem.p.y;
                        win.dragging = true;
                        win.wake();
                    }
                    onPositionChanged: mouse => {
                        const m = mapToItem(win.contentItem, mouse.x, mouse.y);
                        win.dragX = Math.max(4, Math.min(win.width - 4, m.x + offX));
                        win.dragY = Math.max(0, Math.min(win.height - 4, m.y + offY));
                    }
                    onReleased: win.dragging = false
                    onCanceled: win.dragging = false
                }
            }
        }
    }
}
