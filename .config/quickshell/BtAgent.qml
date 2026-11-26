pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// scripts/bt-agent.py ile konuşan BlueZ eşleştirme ajanı.
// Eşleştirmeyi ajanın kendi bağlantısından başlatır; böylece PIN/onay istekleri bize gelir.
Singleton {
    id: root

    // Bekleyen istek: { id, kind: confirm|authorize|pin|passkey, device, name, passkey }
    property var request: null
    // Karşı cihazda girilecek kod: { device, name, code }
    property var display: null
    // dbusPath -> hata mesajı (son eşleştirme denemesi)
    property var errors: ({})
    // Eşleştirilmekte olan cihazlar (dbusPath -> true)
    property var pairing: ({})

    signal requested

    function send(line) {
        if (proc.running)
            proc.write(line + "\n");
    }

    function setMap(name, key, value) {
        const m = Object.assign({}, root[name]);
        if (value === undefined)
            delete m[key];
        else
            m[key] = value;
        root[name] = m;
    }

    function pair(device) {
        const path = device.dbusPath;
        setMap("errors", path, undefined);
        setMap("pairing", path, true);
        if (proc.running)
            send("pair " + path);
        else
            device.pair(); // yardımcı çalışmıyorsa Quickshell ile dene
    }

    function cancelPair(device) {
        send("cancel " + device.dbusPath);
        setMap("pairing", device.dbusPath, undefined);
    }

    function accept(value) {
        if (!root.request)
            return;
        send("reply " + root.request.id + " " + (value ?? "yes"));
        root.request = null;
    }

    function reject() {
        if (!root.request)
            return;
        send("reject " + root.request.id);
        root.request = null;
    }

    Process {
        id: proc
        running: true
        command: ["python3", "-I", Quickshell.shellPath("scripts/bt-agent.py")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.type === "request") {
                    root.request = ev;
                    root.requested();
                } else if (ev.type === "display") {
                    root.display = ev;
                    root.requested();
                } else if (ev.type === "cancel") {
                    root.request = null;
                    root.display = null;
                } else if (ev.type === "paired") {
                    root.setMap("pairing", ev.device, undefined);
                    if (!ev.ok)
                        root.setMap("errors", ev.device, (ev.error || "Pairing failed").trim());
                    if (root.display?.device === ev.device)
                        root.display = null;
                    if (root.request?.device === ev.device)
                        root.request = null;
                }
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: proc.running = true
    }
}
