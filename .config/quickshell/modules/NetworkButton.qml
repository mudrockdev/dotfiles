pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components

BarButton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifi ? wifi.networks.values.find(n => n.connected) ?? null : null

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

    readonly property string iconName: {
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

    onClicked: popup.toggle()

    // Wi-Fi taraması yalnızca menü açıkken
    Connections {
        target: popup
        function onVisibleChanged() {
            if (root.wifi)
                root.wifi.scannerEnabled = popup.visible && Networking.wifiEnabled;
        }
    }

    Popup {
        id: popup
        anchorItem: root
        minWidth: 280

        // Kablolu bağlantılar
        Repeater {
            model: root.devices.filter(d => d.type === DeviceType.Wired)
            delegate: MenuItem {
                required property var modelData
                icon: "network-wired-symbolic"
                text: modelData.network?.name || ("Kablolu (" + modelData.name + ")")
                secondary: modelData.connected ? (modelData.linkSpeed ? modelData.linkSpeed + " Mb/s" : "Bağlı") : "Bağlı değil"
                checked: modelData.connected
                enabled: false
                opacity: 1
            }
        }

        // Kablosuz
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
        Repeater {
            model: root.wifi && Networking.wifiEnabled ? root.wifi.networks.values.slice().sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)).slice(0, 10) : []
            delegate: MenuItem {
                required property var modelData
                icon: root.wifiIcon(modelData.signalStrength)
                text: modelData.name
                checked: modelData.connected
                secondary: modelData.stateChanging ? "…" : modelData.known ? "" : (modelData.security === WifiSecurityType.Open ? "Açık" : "🔒")
                onTriggered: {
                    if (modelData.connected)
                        modelData.disconnect();
                    else if (modelData.known || modelData.security === WifiSecurityType.Open)
                        modelData.connect();
                    else {
                        Quickshell.execDetached(Config.settingsCommand.concat(["wireless"]));
                        popup.visible = false;
                    }
                }
            }
        }

        Separator {}
        MenuItem {
            text: "Ağ ayarları…"
            onTriggered: {
                Quickshell.execDetached(Config.settingsCommand.concat(["network"]));
                popup.visible = false;
            }
        }
    }
}
