pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import qs
import qs.components

// Ses: kaydır = ses seviyesi, orta tık = sessiz, sol tık = menü.
BarButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true

    function volumeIcon(vol, isMuted) {
        if (isMuted || vol <= 0.001)
            return "audio-volume-muted-symbolic";
        if (vol < 0.34)
            return "audio-volume-low-symbolic";
        if (vol < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function setVolume(node, v) {
        if (node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Icon {
        icon: root.volumeIcon(root.volume, root.muted)
    }

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            if (sink?.audio)
                sink.audio.muted = !sink.audio.muted;
        } else {
            popup.toggle();
        }
    }
    onScrolled: wheel => setVolume(sink, volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

    Popup {
        id: popup
        anchorItem: root
        minWidth: 320

        readonly property var player: {
            const ps = Mpris.players.values;
            return ps.find(p => p.isPlaying) ?? ps.find(p => p.canControl) ?? null;
        }

        // Çalan medya
        RowLayout {
            visible: popup.player !== null
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 10

            Image {
                visible: source != ""
                source: popup.player?.trackArtUrl ?? ""
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: popup.player?.trackTitle || popup.player?.identity || ""
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    text: popup.player?.trackArtist ?? ""
                    color: Theme.fgDim
                    visible: text !== ""
                }
            }
        }
        Separator {
            visible: popup.player !== null
        }

        // Çıkış
        SectionTitle {
            text: "Çıkış"
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 8
            BarButton {
                Icon {
                    icon: root.volumeIcon(root.volume, root.muted)
                }
                onClicked: if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted
            }
            Slider {
                value: root.muted ? 0 : root.volume
                onMoved: v => root.setVolume(root.sink, v)
            }
            Label {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100) + "%"
            }
        }
        Repeater {
            model: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
            delegate: MenuItem {
                required property PwNode modelData
                text: modelData.description || modelData.nickname || modelData.name
                checked: Pipewire.defaultAudioSink === modelData
                onTriggered: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        Separator {}

        // Giriş
        SectionTitle {
            text: "Giriş"
        }
        RowLayout {
            id: micRow
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 8
            readonly property real micVol: root.source?.audio?.volume ?? 0
            readonly property bool micMuted: root.source?.audio?.muted ?? true
            BarButton {
                Icon {
                    icon: micRow.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                }
                onClicked: if (root.source?.audio)
                    root.source.audio.muted = !root.source.audio.muted
            }
            Slider {
                value: micRow.micMuted ? 0 : micRow.micVol
                onMoved: v => root.setVolume(root.source, v)
            }
            Label {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(micRow.micVol * 100) + "%"
            }
        }
        Repeater {
            model: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && n.name.startsWith("alsa_input"))
            delegate: MenuItem {
                required property PwNode modelData
                text: modelData.description || modelData.nickname || modelData.name
                checked: Pipewire.defaultAudioSource === modelData
                onTriggered: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        Separator {}
        MenuItem {
            text: "Ses ayarları…"
            onTriggered: {
                Quickshell.execDetached(Config.settingsCommand.concat(["sound"]));
                popup.visible = false;
            }
        }
    }
}
