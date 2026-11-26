pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.WindowManager
import qs
import qs.components

// ext-workspace-v1 üzerinden COSMIC çalışma alanları.
RowLayout {
    id: root

    required property ShellScreen barScreen
    readonly property var projection: barScreen ? WindowManager.screenProjection(barScreen) : null
    readonly property var sets: (projection?.windowsets ?? WindowManager.windowsets).filter(w => w.shouldDisplay)

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

            onClicked: if (modelData.canActivate)
                modelData.activate()
            onScrolled: wheel => root.cycle(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }
}
