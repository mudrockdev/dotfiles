import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// COSMIC xkb_config içindeki düzeni gösterir. Tıklayınca klavye ayarları açılır.
BarButton {
    id: root

    property var layouts: ["?"]

    Label {
        text: root.layouts[0]
    }

    onClicked: Quickshell.execDetached(Config.settingsCommand.concat(["keyboard"]))

    FileView {
        path: Quickshell.env("HOME") + "/.config/cosmic/com.system76.CosmicComp/v1/xkb_config"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = /layout:\s*"([^"]*)"/.exec(text());
            if (m && m[1] !== "")
                root.layouts = m[1].split(",").map(s => s.trim());
        }
    }
}
