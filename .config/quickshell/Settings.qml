pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Panelden değiştirilen kalıcı ayarlar (~/.local/state/quickshell/.../settings.json).
Singleton {
    id: root

    property alias showMediaControls: adapter.showMediaControls

    FileView {
        path: Quickshell.statePath("settings.json")
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool showMediaControls: true
        }
    }
}
