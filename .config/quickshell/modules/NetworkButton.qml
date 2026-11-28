pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components

// COSMIC ağ appleti: VPN'ler (NetworkManager + Tailscale), kablolu bağlantılar,
// Wi-Fi (yalnızca Wi-Fi aygıtı varsa; açıkken bilinen + yakındaki ağlar, satır içi parola).
BarButton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wiredDevs: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var wired: wiredDevs.find(d => d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNets: wifi && Networking.wifiEnabled ? wifi.networks.values : []
    readonly property var wifiNet: wifiNets.find(n => n.connected) ?? null
    readonly property var knownNets: wifiNets.filter(n => n.known).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
    readonly property var otherNets: wifiNets.filter(n => !n.known && n.name !== "").sort((a, b) => b.signalStrength - a.signalStrength)

    // Parola istenen Wi-Fi ağı ve hata metni
    property var pskNetwork: null
    property string pskError: ""
    property bool pskBusy: false
    property bool showExitNodes: false

    function wifiIcon(strength) {
        if (strength > 0.8)
            return "network-wireless-signal-excellent-symbolic";
        if (strength > 0.55)
            return "network-wireless-signal-good-symbolic";
        if (strength > 0.3)
            return "network-wireless-signal-ok-symbolic";
        if (strength > 0.05)
            return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }

    function ipOf(dev) {
        return dev ? (Net.addresses[dev.name] ?? [])[0] ?? "" : "";
    }

    function failText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "Wrong or missing password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Authentication timed out";
        case ConnectionFailReason.WifiNetworkLost:
            return "Network lost";
        default:
            return "Could not connect";
        }
    }

    function openPsk(net, error) {
        root.pskError = error ?? "";
        root.pskBusy = false;
        root.pskNetwork = net;
    }

    readonly property string iconName: {
        if (Net.airplaneMode)
            return "airplane-mode-symbolic";
        if (wired)
            return "network-wired-symbolic";
        if (wifiNet)
            return wifiIcon(wifiNet.signalStrength);
        if (wifi && Networking.wifiEnabled)
            return "network-wireless-offline-symbolic";
        return "network-offline-symbolic";
    }

    Icon {
        icon: root.iconName
    }
    Icon {
        visible: Net.vpnActive
        icon: "network-vpn-symbolic"
        size: 12
        y: 2
    }

    onClicked: {
        Net.refresh();
        Net.refreshTailscale();
        popup.toggle();
    }

    // Wi-Fi taraması yalnızca menü açıkken
    Connections {
        target: popup
        function onVisibleChanged() {
            if (root.wifi)
                root.wifi.scannerEnabled = popup.visible && Networking.wifiEnabled;
            if (!popup.visible) {
                root.pskNetwork = null;
                root.showExitNodes = false;
                Net.vpnPasswordFor = "";
            }
        }
    }

    Popup {
        id: popup
        anchorItem: root
        minWidth: 300
        maxWidth: 360

        // ---------- VPN ----------
        SectionTitle {
            id: vpnTitle
            visible: Net.vpns.length > 0 || Net.tsAvailable
            text: "VPN"
        }

        Repeater {
            model: Net.vpns

            delegate: ColumnLayout {
                id: vpnRow
                required property var modelData
                readonly property string err: Net.vpnErrors[modelData.uuid] ?? ""
                Layout.fillWidth: true
                spacing: 0

                Toggle {
                    text: vpnRow.modelData.name
                    icon: "network-vpn-symbolic"
                    bold: false
                    checked: vpnRow.modelData.state === "activated" || vpnRow.modelData.state === "activating"
                    subtitle: vpnRow.modelData.state === "activating" ? "Connecting…" : vpnRow.modelData.state === "deactivating" ? "Disconnecting…" : vpnRow.err !== "" && Net.vpnPasswordFor !== vpnRow.modelData.uuid ? vpnRow.err : vpnRow.modelData.state === "activated" ? "Connected" : ""
                    onToggled: checked ? Net.vpnDown(vpnRow.modelData.uuid) : Net.vpnUp(vpnRow.modelData.uuid)
                }
                Loader {
                    Layout.fillWidth: true
                    active: Net.vpnPasswordFor === vpnRow.modelData.uuid
                    visible: active
                    sourceComponent: PasswordField {
                        error: vpnRow.err
                        onAccepted: text => Net.vpnUp(vpnRow.modelData.uuid, text)
                        onCanceled: Net.vpnPasswordFor = ""
                    }
                }
            }
        }

        // Tailscale
        Toggle {
            visible: Net.tsAvailable
            text: "Tailscale"
            icon: "network-vpn-symbolic"
            bold: false
            checked: Net.tsRunning
            subtitle: {
                if (Net.tsBusy)
                    return "…";
                if (Net.tsRunning) {
                    const exit = Net.tsExitNodes.find(n => n.ip === Net.tsExitNode);
                    return Net.tsIp + (exit ? " · exit: " + exit.name : "");
                }
                if (Net.tsState === "NeedsLogin")
                    return "Login required";
                return Net.tsState === "" ? "Service not running" : "Off";
            }
            onToggled: Net.tsRunning ? Net.tsDown() : Net.tsUp()
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            visible: Net.tsAvailable && Net.tsError !== ""
            text: Net.tsError
            color: Theme.accent
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }
        MenuItem {
            visible: Net.tsAvailable && Net.tsRunning && Net.tsIp !== ""
            text: "Copy IP address"
            secondary: Net.tsIp
            icon: "edit-copy-symbolic"
            onTriggered: {
                Quickshell.clipboardText = Net.tsIp;
                popup.visible = false;
            }
        }
        MenuItem {
            visible: Net.tsAvailable && Net.tsRunning && Net.tsExitNodes.length > 0
            text: "Exit node"
            icon: "network-server-symbolic"
            secondary: Net.tsExitNodes.find(n => n.ip === Net.tsExitNode)?.name ?? "None"
            trailingIcon: root.showExitNodes ? "go-down-symbolic" : "go-next-symbolic"
            onTriggered: root.showExitNodes = !root.showExitNodes
        }
        Repeater {
            model: root.showExitNodes && Net.tsRunning ? [
                {
                    name: "None",
                    ip: "",
                    online: true
                }
            ].concat(Net.tsExitNodes) : []

            delegate: MenuItem {
                required property var modelData
                Layout.leftMargin: 24
                text: modelData.name
                secondary: modelData.online ? "" : "offline"
                checked: modelData.ip === Net.tsExitNode
                enabled: modelData.online && !Net.tsBusy
                onTriggered: Net.tsSetExitNode(modelData.ip)
            }
        }

        // ---------- Kablolu ----------
        Separator {
            visible: root.wiredDevs.length > 0
        }
        Repeater {
            model: root.wiredDevs

            delegate: MenuItem {
                id: wiredRow
                required property var modelData
                readonly property string ip: root.ipOf(modelData)
                icon: "network-wired-symbolic"
                text: "Wired" + (root.wiredDevs.length > 1 ? " (" + modelData.name + ")" : "")
                checked: modelData.connected
                subtitle: modelData.connected ? [ip, modelData.linkSpeed ? modelData.linkSpeed + " Mb/s" : ""].filter(s => s).join(" · ") : modelData.hasLink ? "Disconnected" : "Cable unplugged"
                actionIcon: ip !== "" ? "edit-copy-symbolic" : ""
                onActionTriggered: Quickshell.clipboardText = ip
                // Bağlıyken yanlışlıkla kesmemek için yalnızca bağlanır
                onTriggered: if (!modelData.connected && modelData.network)
                    modelData.network.connect()
            }
        }

        // ---------- Wi-Fi ----------
        Separator {
            visible: root.wifi !== null
        }
        Toggle {
            visible: root.wifi !== null
            text: "Wi-Fi"
            icon: "network-wireless-symbolic"
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }

        Component {
            id: wifiRow

            ColumnLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                spacing: 0

                Connections {
                    target: row.modelData
                    function onConnectionFailed(reason) {
                        if (root.pskNetwork === row.modelData || reason === ConnectionFailReason.NoSecrets)
                            root.openPsk(row.modelData, root.failText(reason));
                    }
                    function onConnectedChanged() {
                        if (row.modelData.connected && root.pskNetwork === row.modelData)
                            root.pskNetwork = null;
                    }
                }

                MenuItem {
                    readonly property bool secured: row.modelData.security !== WifiSecurityType.Open
                    icon: root.wifiIcon(row.modelData.signalStrength)
                    text: row.modelData.name
                    checked: row.modelData.connected
                    subtitle: row.modelData.stateChanging ? (row.modelData.connected ? "Disconnecting…" : "Connecting…") : row.modelData.connected ? root.ipOf(root.wifi) : ""
                    trailingIcon: !row.modelData.known && secured ? "network-wireless-encrypted-symbolic" : ""
                    actionIcon: row.modelData.known ? "user-trash-symbolic" : ""
                    onActionTriggered: row.modelData.forget()
                    onTriggered: {
                        const n = row.modelData;
                        if (n.connected)
                            n.disconnect();
                        else if (n.known || !secured)
                            n.connect();
                        else
                            root.openPsk(n);
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.pskNetwork === row.modelData
                    visible: active
                    sourceComponent: PasswordField {
                        error: root.pskError
                        busy: root.pskBusy && row.modelData.stateChanging
                        onAccepted: text => {
                            root.pskError = "";
                            root.pskBusy = true;
                            row.modelData.connectWithPsk(text);
                        }
                        onCanceled: root.pskNetwork = null
                    }
                }
            }
        }

        Repeater {
            model: root.knownNets
            delegate: wifiRow
        }

        // Yakındaki (bilinmeyen) ağlar: Wi-Fi açıkken doğrudan listelenir
        SectionTitle {
            visible: root.otherNets.length > 0
            text: "Nearby networks"
        }
        Repeater {
            model: root.otherNets.slice(0, 10)
            delegate: wifiRow
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            visible: root.wifi !== null && Networking.wifiEnabled && root.wifiNets.length === 0
            text: "Searching for networks…"
            color: Theme.fgDim
        }

        Separator {}
        MenuItem {
            text: "Network settings…"
            onTriggered: {
                Quickshell.execDetached(Config.settingsCommand.concat(["network"]));
                popup.visible = false;
            }
        }
    }
}
