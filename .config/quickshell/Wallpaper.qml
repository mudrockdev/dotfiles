pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Duvar kağıdı; çalışma alanı önizlemesinde kullanılır.
// Aura (mpvpaper canlı duvar kağıdı) çalışıyorsa onun o anki karesi (scripts/aura-frame.py),
// değilse COSMIC duvar kağıdı (com.system76.CosmicBackground).
// Kaynak: Path("dosya") -> resim, Color(Single/Gradient) -> düz renk. Klasör (slayt gösterisi)
// kaynağında resim yüklenemez, renk/koyu arka plana düşülür.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/cosmic/com.system76.CosmicBackground/v1/"

    property bool sameOnAll: true
    property var all: ({ path: "", color: "#000000", mode: "zoom" })
    property var perOutput: ({})
    // ekran adı -> Aura karesinin URL'si (Aura kapalıysa girdi yok)
    property var auraFrames: ({})

    // { path: "file://..." | "", color, mode: "zoom" | "fit" | "stretch" }
    function forScreen(name) {
        if (root.auraFrames[name])
            return { path: root.auraFrames[name], color: "#000000", mode: "zoom" };
        if (!root.sameOnAll && root.perOutput[name])
            return root.perOutput[name];
        return root.all;
    }

    function parse(text) {
        const out = { path: "", color: "#000000", mode: "zoom" };
        const p = /source:\s*Path\(\s*"((?:[^"\\]|\\.)*)"/.exec(text);
        if (p)
            out.path = "file://" + p[1].replace(/\\(.)/g, "$1");
        const c = /source:\s*Color\(\s*(?:Single|Gradient)\D*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/.exec(text);
        if (c)
            out.color = Qt.rgba(parseFloat(c[1]), parseFloat(c[2]), parseFloat(c[3]), 1);
        const m = /scaling_mode:\s*(\w+)/.exec(text);
        if (m)
            out.mode = m[1].toLowerCase();
        return out;
    }

    // Aura'nın o anki karesini yeniden çıkar (önizleme açılınca çağrılır; ~0.5-1 sn).
    // Hazır olana kadar önceki kare gösterilmeye devam eder.
    function refreshAura(name, width) {
        auraProc.createObject(root, { screenName: name, width: width });
    }

    Component {
        id: auraProc

        Process {
            id: proc
            required property string screenName
            required property int width
            readonly property string target: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-previews/wall-" + screenName + ".jpg"

            command: ["python3", "-I", Quickshell.shellPath("scripts/aura-frame.py"), screenName, target, String(width)]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    let path = "";
                    try {
                        path = JSON.parse(text).path;
                    } catch (e) {}
                    const f = Object.assign({}, root.auraFrames);
                    if (path)
                        f[proc.screenName] = "file://" + path + "?" + Date.now();
                    else
                        delete f[proc.screenName];
                    root.auraFrames = f;
                }
            }
            onExited: destroy()
        }
    }

    FileView {
        path: root.dir + "same-on-all"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.sameOnAll = text().trim() !== "false"
    }

    FileView {
        path: root.dir + "all"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.all = root.parse(text())
    }

    Variants {
        model: Quickshell.screens

        FileView {
            required property ShellScreen modelData
            path: root.dir + "output." + modelData.name
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                const p = Object.assign({}, root.perOutput);
                p[modelData.name] = root.parse(text());
                root.perOutput = p;
            }
        }
    }
}
