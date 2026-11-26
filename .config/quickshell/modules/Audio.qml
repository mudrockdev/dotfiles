pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components

// Ses: kaydır = ses seviyesi, orta tık = sessiz, sol tık = menü.
BarButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? true

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !n.name.endsWith(".monitor"))

    function volumeIcon(vol, isMuted) {
        if (isMuted || vol <= 0.001)
            return "audio-volume-muted-symbolic";
        if (vol < 0.34)
            return "audio-volume-low-symbolic";
        if (vol < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function setVolume(node, v, max) {
        if (node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(max, v));
        }
    }

    function toggleMute(node) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    Icon {
        icon: root.volumeIcon(root.volume, root.muted)
    }

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            toggleMute(sink);
        else
            popup.toggle();
    }
    onScrolled: wheel => setVolume(sink, volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05), 1.0)

    Popup {
        id: popup
        anchorItem: root
        minWidth: 360
        maxWidth: 400

        // Çıkış ses seviyesi
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            BarButton {
                Icon {
                    icon: root.volumeIcon(root.volume, root.muted)
                    size: 20
                }
                onClicked: root.toggleMute(root.sink)
            }
            Slider {
                value: root.muted ? 0 : root.volume
                to: Math.max(1.0, root.volume)
                onMoved: v => root.setVolume(root.sink, v, 1.5)
            }
            Label {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100)
                font.pixelSize: Theme.fontSize + 2
            }
        }

        // Mikrofon ses seviyesi (%150'ye kadar, %100'de işaret)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            BarButton {
                Icon {
                    icon: root.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                    size: 20
                }
                onClicked: root.toggleMute(root.source)
            }
            Slider {
                value: root.micMuted ? 0 : root.micVolume
                to: 1.5
                mark: 1.0
                onMoved: v => root.setVolume(root.source, v, 1.5)
            }
            Label {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.micVolume * 100)
                font.pixelSize: Theme.fontSize + 2
            }
        }

        Separator {}

        DeviceSection {
            title: "Çıkış"
            nodes: root.sinks
            current: root.sink
            onSelected: node => Pipewire.preferredDefaultAudioSink = node
        }
        DeviceSection {
            title: "Giriş"
            nodes: root.sources
            current: root.source
            onSelected: node => Pipewire.preferredDefaultAudioSource = node
        }

        // Medya kaynakları
        Separator {
            visible: Players.list.length > 0
        }
        Repeater {
            model: Players.list
            delegate: PlayerRow {
                required property var modelData
                player: modelData
            }
        }

        Separator {}
        Toggle {
            text: "Panelde medya kontrollerini göster"
            checked: Settings.showMediaControls
            onToggled: Settings.showMediaControls = !Settings.showMediaControls
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
