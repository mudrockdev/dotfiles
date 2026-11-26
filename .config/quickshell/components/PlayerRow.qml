import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Tek bir MPRIS oynatıcısı: kapak, başlık, sanatçı, önceki/oynat/sonraki.
RowLayout {
    id: root

    required property var player

    Layout.fillWidth: true
    Layout.leftMargin: 8
    spacing: 10

    Item {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40

        Image {
            id: art
            anchors.fill: parent
            source: root.player.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 80
            sourceSize.height: 80
            visible: status === Image.Ready
        }
        Icon {
            anchors.centerIn: parent
            visible: !art.visible
            size: 32
            colorize: false
            icon: DesktopEntries.heuristicLookup(root.player.desktopEntry)?.icon ?? "audio-x-generic"
            fallback: "audio-x-generic"
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
            Layout.fillWidth: true
            text: root.player.trackTitle || root.player.identity
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
        Label {
            Layout.fillWidth: true
            text: root.player.trackArtist || root.player.identity
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
        }
    }

    BarButton {
        enabled: root.player.canGoPrevious
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
            icon: root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
        }
        onClicked: Players.toggle(root.player)
    }
    BarButton {
        enabled: root.player.canGoNext
        opacity: enabled ? 1 : 0.4
        Icon {
            icon: "media-skip-forward-symbolic"
        }
        onClicked: root.player.next()
    }
}
