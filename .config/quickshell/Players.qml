pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// MPRIS oynatıcıları ve paneldeki "etkin" oynatıcının seçimi.
Singleton {
    id: root

    // playerctld, başka bir oynatıcının vekilidir; çift görünmesin.
    readonly property var list: Mpris.players.values.filter(p => !p.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld"))

    // En son çalmaya başlayan oynatıcı
    property var lastActive: null

    // Çalan > en son çalan > oynatılabilir > ilk
    readonly property var active: list.find(p => p.isPlaying) ?? (list.includes(lastActive) ? lastActive : null) ?? list.find(p => p.canPlay) ?? list[0] ?? null

    function canToggle(p) {
        return p !== null && (p.isPlaying ? p.canPause : p.canPlay);
    }

    function toggle(p) {
        if (!p)
            return;
        if (p.isPlaying) {
            if (p.canPause)
                p.pause();
        } else if (p.canPlay) {
            p.play();
        }
    }

    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.lastActive = modelData;
            }
        }
    }
}
