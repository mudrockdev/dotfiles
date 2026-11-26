pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell.Networking'in kapsamadığı ağ bilgileri:
// NetworkManager VPN/WireGuard bağlantıları, IP adresleri, uçak modu (rfkill) ve Tailscale.
Singleton {
    id: root

    // --- NetworkManager VPN ---
    // [{ name, uuid, type, state: "" | "activating" | "activated" | "deactivating" }]
    property var vpns: []
    // uuid -> "hata mesajı"
    property var vpnErrors: ({})
    // parola isteyen VPN'in uuid'si (satır altında parola alanı açılır)
    property string vpnPasswordFor: ""
    readonly property bool vpnActive: vpns.some(v => v.state === "activated") || tsRunning

    // --- IP adresleri: arayüz adı -> ["192.168.1.2", ...] ---
    property var addresses: ({})

    // --- Uçak modu: tüm rfkill cihazları yazılımsal olarak engelli ---
    property bool airplaneMode: false
    property bool hasRfkill: false

    // --- Tailscale ---
    property bool tsAvailable: false
    property string tsState: ""          // Running, Stopped, NeedsLogin, ...
    readonly property bool tsRunning: tsState === "Running"
    property string tsIp: ""
    property string tsName: ""
    property string tsExitNode: ""       // etkin çıkış düğümünün IP'si
    property var tsExitNodes: []         // [{ name, ip, online }]
    property string tsError: ""
    property bool tsBusy: false

    // ---------------------------------------------------------------

    function refresh() {
        if (!nmList.running)
            nmList.running = true;
        if (!ipList.running)
            ipList.running = true;
    }

    function refreshTailscale() {
        if (root.tsAvailable && !tsStatus.running)
            tsStatus.running = true;
    }

    // Komutu çalıştır, bitince cb(code, stdout, stderr) çağır. input verilirse stdin'e yazılır.
    function run(cmd, cb, input) {
        const p = procComp.createObject(root, {
            command: cmd,
            cb: cb ?? null,
            input: input ?? ""
        });
        p.running = true;
    }

    function setVpnError(uuid, msg) {
        const e = Object.assign({}, root.vpnErrors);
        if (msg)
            e[uuid] = msg;
        else
            delete e[uuid];
        root.vpnErrors = e;
    }

    function vpnUp(uuid, password) {
        setVpnError(uuid, "");
        root.vpnPasswordFor = "";
        const cmd = ["nmcli", "--wait", "60", "connection", "up", "uuid", uuid];
        let input = "";
        if (password !== undefined) {
            cmd.push("passwd-file", "/dev/stdin");
            input = "vpn.secrets.password:" + password + "\n";
        }
        run(cmd, (code, out, err) => {
            if (code === 0)
                return;
            if (/secrets were required|no agents were available|password/i.test(err))
                root.vpnPasswordFor = uuid;
            setVpnError(uuid, root.cleanError(err));
        }, input);
        root.refresh();
    }

    function vpnDown(uuid) {
        setVpnError(uuid, "");
        run(["nmcli", "connection", "down", "uuid", uuid], (code, out, err) => {
            if (code !== 0)
                setVpnError(uuid, root.cleanError(err));
        });
    }

    function setAirplaneMode(on) {
        run(["rfkill", on ? "block" : "unblock", "all"], () => rfList.running = true);
    }

    function tsRun(args) {
        root.tsError = "";
        root.tsBusy = true;
        run(["tailscale"].concat(args), (code, out, err) => {
            root.tsBusy = false;
            if (code !== 0)
                root.tsError = /access denied|checkprefs|operator/i.test(err) ? "İzin yok. Bir kez çalıştırın: sudo tailscale set --operator=$USER" : root.cleanError(err || out);
            root.refreshTailscale();
        });
    }
    function tsUp() {
        tsRun(["up"]);
    }
    function tsDown() {
        tsRun(["down"]);
    }
    function tsSetExitNode(ip) {
        tsRun(["set", "--exit-node=" + (ip ?? "")]);
    }

    function cleanError(s) {
        s = (s || "").trim().split("\n").filter(l => l.trim() !== "").pop() ?? "";
        return s.replace(/^Error:\s*/i, "").slice(0, 200);
    }

    // nmcli -t çıktısı: ':' ayraç, '\:' kaçışlı
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    // ---------------------------------------------------------------

    Component {
        id: procComp

        Process {
            id: proc

            property var cb: null
            property string input: ""

            stdinEnabled: input !== ""
            stdout: StdioCollector {
                id: pOut
            }
            stderr: StdioCollector {
                id: pErr
            }
            onStarted: {
                if (input !== "") {
                    write(input);
                    stdinEnabled = false;
                }
            }
            onExited: code => {
                if (cb)
                    cb(code, pOut.text, pErr.text);
                proc.destroy();
            }
        }
    }

    Process {
        id: nmList
        command: ["nmcli", "-t", "-e", "yes", "-f", "NAME,UUID,TYPE,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const [name, uuid, type, state] = root.splitTerse(line);
                    if (type === "vpn" || type === "wireguard")
                        list.push({
                            name,
                            uuid,
                            type,
                            state
                        });
                }
                list.sort((a, b) => a.name.localeCompare(b.name));
                root.vpns = list;
            }
        }
    }

    Process {
        id: ipList
        command: ["ip", "-j", "addr"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {};
                    for (const itf of JSON.parse(text))
                        map[itf.ifname] = (itf.addr_info || []).filter(a => a.family === "inet").map(a => a.local);
                    root.addresses = map;
                } catch (e) {}
            }
        }
    }

    // NetworkManager değişikliklerini izle; kısa gecikmeyle yenile
    Process {
        id: nmMon
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
        onExited: restartMon.start()
    }
    Timer {
        id: restartMon
        interval: 5000
        onTriggered: nmMon.running = true
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.refresh()
    }

    // --- rfkill ---
    Process {
        id: rfList
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devs = (JSON.parse(text).rfkilldevices) || [];
                    root.hasRfkill = devs.length > 0;
                    root.airplaneMode = devs.length > 0 && devs.every(d => d.soft === "blocked");
                } catch (e) {}
            }
        }
    }
    Process {
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser {
            onRead: rfDebounce.restart()
        }
    }
    Timer {
        id: rfDebounce
        interval: 150
        onTriggered: rfList.running = true
    }

    // --- Tailscale ---
    Process {
        running: true
        command: ["sh", "-c", "command -v tailscale"]
        onExited: code => {
            root.tsAvailable = code === 0;
            root.refreshTailscale();
        }
    }

    Process {
        id: tsStatus
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.tsState = d.BackendState || "";
                    root.tsIp = (d.Self?.TailscaleIPs || []).find(ip => ip.includes(".")) ?? "";
                    root.tsName = d.Self?.HostName ?? "";
                    const peers = Object.values(d.Peer || {});
                    const exit = peers.find(p => p.ExitNode);
                    root.tsExitNode = exit ? (exit.TailscaleIPs || [])[0] ?? "" : "";
                    root.tsExitNodes = peers.filter(p => p.ExitNodeOption).map(p => ({
                                name: p.HostName,
                                ip: (p.TailscaleIPs || [])[0] ?? "",
                                online: !!p.Online
                            })).sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
                } catch (e) {
                    root.tsState = "";
                }
            }
        }
    }

    Timer {
        running: root.tsAvailable
        repeat: true
        interval: 5000
        onTriggered: root.refreshTailscale()
    }

    Component.onCompleted: {
        refresh();
        rfList.running = true;
    }
}
