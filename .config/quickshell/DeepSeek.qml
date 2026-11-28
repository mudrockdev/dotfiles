pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// DeepSeek-chan: Live2D masaüstü karakteri, seçili ekranın sağ altında (varsayılan kapalı).
// Çizimi live2d/deepseek.py yapar (GTK + WebKit katman penceresi); Quickshell'in kendi
// süreci QtWebEngine ile çöküyor. Model ve Cubism Core depoda değil, kullanıcı koyar:
//   ~/.var/deepseek-chan-live2d/DeepSeek/*.model3.json
//   ~/.var/deepseek-chan-live2d/live2dcubismcore.min.js
// JS bağımlılıkları: live2d/ içinde `bun install`.
Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("live2d").toString().replace("file://", "")
    readonly property string dataDir: Quickshell.env("HOME") + "/.var/deepseek-chan-live2d"
    // Model, Cubism Core ve node_modules yerinde mi; eksik olanın açıklaması
    property bool available: false
    property string missing: ""

    readonly property var screen: {
        const want = Settings.deepseekScreen;
        return Quickshell.screens.find(s => s.name === want) ?? Quickshell.screens[0] ?? null;
    }
    readonly property bool enabled: Settings.deepseek && available && screen !== null
    readonly property bool fullBody: Settings.deepseekFraming === "full"
    // Pencere yüksekliği. Üst gövdede karakter aynı yükseklikte ~1.7 kat büyük görünür;
    // boyutlar yine de biraz daha büyük tutulur.
    readonly property int height: (fullBody ? { small: 420, medium: 560, large: 720 } : { small: 380, medium: 480, large: 600 })[Settings.deepseekSize] ?? 480
    // Bunlar değişince yardımcı yeniden başlar (katman değişimi stdin'den gider)
    readonly property string launchKey: enabled ? [screen.x, screen.y, height, Settings.deepseekFraming].join(",") : ""

    function check() {
        checker.running = true;
    }

    Component.onCompleted: check()

    Process {
        id: checker
        command: ["sh", "-c", `
            d="$1"; m="$2"
            [ -f "$d/live2dcubismcore.min.js" ] || { echo "Cubism Core (live2dcubismcore.min.js) missing in ~/.var/deepseek-chan-live2d"; exit; }
            ls "$d"/*/*.model3.json >/dev/null 2>&1 || { echo "Model (*.model3.json) missing in ~/.var/deepseek-chan-live2d"; exit; }
            [ -d "$m/node_modules/untitled-pixi-live2d-engine" ] || { echo "Run 'bun install' in ~/.config/quickshell/live2d"; exit; }
            command -v python3 >/dev/null || { echo "python3 not found"; exit; }`, "sh", root.dataDir, root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.missing = text.trim();
                root.available = root.missing === "";
            }
        }
    }

    Process {
        id: helper
        command: ["python3", root.dir + "/deepseek.py", "--x", String(root.screen?.x ?? 0), "--y", String(root.screen?.y ?? 0), "--height", String(root.height), "--framing", fullBody ? "full" : "upper", "--layer", Settings.deepseekOverApps ? "top" : "bottom"]
        // stdin açık kalmalı: kapanınca yardımcı çıkar (Quickshell kapanınca o da kapanır)
        stdinEnabled: true
        // Yalnızca sayfadaki hatalar günlüğe gitsin
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("page: error") || line.startsWith("page: rejection"))
                    console.warn("deepseek:", line);
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (!line.startsWith("libva info"))
                    console.warn("deepseek:", line);
            }
        }
        onExited: code => {
            if (code !== 0 && root.enabled)
                console.warn("deepseek: helper exited with code", code);
        }
    }

    onLaunchKeyChanged: {
        helper.running = false;
        if (launchKey !== "")
            restart.restart();
    }
    // Eski süreç kapanmadan yenisi başlamasın
    Timer {
        id: restart
        interval: 300
        onTriggered: helper.running = root.launchKey !== ""
    }

    Connections {
        target: Settings
        function onDeepseekOverAppsChanged() {
            if (helper.running)
                helper.write("layer " + (Settings.deepseekOverApps ? "top" : "bottom") + "\n");
        }
    }

    // Menüden durum tetiklemek için (ör. "wave")
    function act(state) {
        if (helper.running)
            helper.write("state " + state + "\n");
    }
}
