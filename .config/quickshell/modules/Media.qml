import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// MPRIS medya kontrolleri (önceki / oynat-duraklat / sonraki).
RowLayout {
    id: root

    readonly property var player: Players.active

    visible: Settings.showMediaControls && player !== null
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
        enabled: Players.canToggle(root.player)
        opacity: enabled ? 1 : 0.4
        Icon {
            icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
        }
        onClicked: Players.toggle(root.player)
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
