pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// COSMIC pencere listesi. COSMIC wlr-foreign-toplevel sunmadığı için
// Quickshell'in ToplevelManager'ı boş kalır; bunun yerine COSMIC'in kendi
// protokollerini konuşan scripts/cosmic-toplevels.py kullanılır.
Singleton {
    id: root

    // [{ id, appId, title, activated, minimized, maximized, fullscreen,
    //    workspaces: [{ id, name, outputs }], geometry: { output, x, y, w, h } | null }]
    property var list: []
    // pencere id -> önizleme görüntüsü URL'si
    property var previews: ({})

    readonly property string previewDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-previews"

    // Pencerenin küçük bir önizlemesini yakalat (sonuç previews[id] içine gelir).
    function capture(t) {
        proc.write("capture " + t.id + " " + previewDir + "/" + t.id + ".ppm 480 270\n");
    }

    // Pencere, verilen çalışma alanında (Quickshell Windowset) ve ekranda mı?
    // COSMIC çalışma alanı kimliği göndermiyor; ad + çıkış adı ile eşleştirilir.
    function onWorkspace(t, ws, screenName) {
        return (t.workspaces ?? []).some(w => {
            const same = w.id !== "" && ws.id ? w.id === ws.id : w.name === ws.name;
            return same && (w.outputs.length === 0 || !screenName || w.outputs.includes(screenName));
        });
    }

    function activate(t) {
        proc.write("activate " + t.id + "\n");
    }
    function minimize(t) {
        proc.write("minimize " + t.id + "\n");
    }
    function close(t) {
        proc.write("close " + t.id + "\n");
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.shellPath("scripts/cosmic-toplevels.py")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    if (msg.type === "toplevels") {
                        root.list = msg.list;
                    } else if (msg.type === "preview" && msg.ok) {
                        const p = Object.assign({}, root.previews);
                        p[msg.id] = "file://" + msg.path + "?" + Date.now();
                        root.previews = p;
                    }
                } catch (e) {
                    console.warn("cosmic-toplevels: invalid output:", data);
                }
            }
        }
        onExited: (code, status) => {
            root.list = [];
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: proc.running = true
    }
}
