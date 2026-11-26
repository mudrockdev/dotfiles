pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// COSMIC pencere listesi. COSMIC wlr-foreign-toplevel sunmadığı için
// Quickshell'in ToplevelManager'ı boş kalır; bunun yerine COSMIC'in kendi
// protokollerini konuşan scripts/cosmic-toplevels.py kullanılır.
Singleton {
    id: root

    // [{ id, appId, title, activated, minimized, maximized, fullscreen }]
    property var list: []

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
                    root.list = JSON.parse(data);
                } catch (e) {
                    console.warn("cosmic-toplevels: geçersiz çıktı:", data);
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
