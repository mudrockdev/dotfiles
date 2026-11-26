pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// /proc ve /sys'ten CPU, sıcaklık, RAM ve ağ hızı.
Singleton {
    id: root

    property real cpu: 0          // yüzde
    property real temp: 0         // °C
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real rxBps: 0        // bit/s
    property real txBps: 0

    property var _lastCpu: null
    property var _lastNet: null
    property string _tempPath: ""

    function formatBits(bps) {
        if (bps >= 1e9) return (bps / 1e9).toFixed(1) + " Gbps";
        if (bps >= 1e6) return (bps / 1e6).toFixed(1) + " Mbps";
        if (bps >= 1e3) return (bps / 1e3).toFixed(1) + " Kbps";
        return Math.round(bps) + " bps";
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            if (root._tempPath !== "")
                tempFile.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const line = text().split("\n")[0];
            const v = line.trim().split(/\s+/).slice(1, 9).map(Number);
            const idle = v[3] + v[4];
            const total = v.reduce((a, b) => a + b, 0);
            const last = root._lastCpu;
            if (last && total > last.total)
                root.cpu = 100 * (1 - (idle - last.idle) / (total - last.total));
            root._lastCpu = { idle: idle, total: total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const total = Number(/MemTotal:\s+(\d+)/.exec(t)[1]);
            const avail = Number(/MemAvailable:\s+(\d+)/.exec(t)[1]);
            root.memTotalGiB = total / 1048576;
            root.memUsedGiB = (total - avail) / 1048576;
        }
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            const lines = text().split("\n").slice(2);
            for (const l of lines) {
                const idx = l.indexOf(":");
                if (idx < 0) continue;
                const name = l.slice(0, idx).trim();
                if (Config.netIgnorePrefixes.some(p => name.startsWith(p))) continue;
                const f = l.slice(idx + 1).trim().split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now();
            const last = root._lastNet;
            if (last) {
                const dt = (now - last.time) / 1000;
                if (dt > 0) {
                    root.rxBps = Math.max(0, (rx - last.rx) * 8 / dt);
                    root.txBps = Math.max(0, (tx - last.tx) * 8 / dt);
                }
            }
            root._lastNet = { rx: rx, tx: tx, time: now };
        }
    }

    FileView {
        id: tempFile
        path: root._tempPath
        printErrors: false
        onLoaded: root.temp = Number(text().trim()) / 1000
    }

    Process {
        running: true
        command: ["sh", "-c",
            'for s in "$@"; do for h in /sys/class/hwmon/hwmon*; do ' +
            '[ "$(cat "$h/name" 2>/dev/null)" = "$s" ] && [ -r "$h/temp1_input" ] && { echo "$h/temp1_input"; exit 0; }; ' +
            'done; done', "sh"].concat(Config.tempSensors)
        stdout: StdioCollector {
            onStreamFinished: root._tempPath = text.trim()
        }
    }
}
