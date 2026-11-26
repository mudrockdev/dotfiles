import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.components

// MPRIS medya kontrolleri (önceki / oynat-duraklat / sonraki).
RowLayout {
    id: root

    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => p.canControl) ?? null;
    }

    visible: player !== null
    spacing: 0

    BarButton {
        enabled: root.player?.canGoPrevious ?? false
        opacity: enabled ? 1 : 0.4
        Icon {
            icon: "media-skip-backward-symbolic"
        }
        onClicked: root.player.previous()
    }
    BarButton {
        Icon {
            icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
        }
        onClicked: root.player.togglePlaying()
    }
    BarButton {
        enabled: root.player?.canGoNext ?? false
        opacity: enabled ? 1 : 0.4
        Icon {
            icon: "media-skip-forward-symbolic"
        }
        onClicked: root.player.next()
    }
}
