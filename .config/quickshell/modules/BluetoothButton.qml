pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components

BarButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values.filter(d => d.paired || d.connected) : []
    readonly property bool anyConnected: devices.some(d => d.connected)

    visible: adapter !== null

    Icon {
        icon: !root.adapter?.enabled ? "bluetooth-disabled-symbolic" : root.anyConnected ? "bluetooth-active-symbolic" : "bluetooth-active-symbolic"
        opacity: root.adapter?.enabled && !root.anyConnected ? 0.75 : 1
    }

    onClicked: popup.toggle()

    Popup {
        id: popup
        anchorItem: root

        Toggle {
            text: "Bluetooth"
            icon: "bluetooth-active-symbolic"
            checked: root.adapter?.enabled ?? false
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }

        Separator {
            visible: (root.adapter?.enabled ?? false) && root.devices.length > 0
        }

        Repeater {
            model: root.adapter?.enabled ? root.devices : []
            delegate: MenuItem {
                required property BluetoothDevice modelData
                text: modelData.name || modelData.deviceName || modelData.address
                icon: (modelData.icon || "bluetooth") + "-symbolic"
                checked: modelData.connected
                secondary: modelData.state === BluetoothDeviceState.Connecting ? "Bağlanıyor…" : modelData.state === BluetoothDeviceState.Disconnecting ? "Kesiliyor…" : modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : modelData.connected ? "Bağlı" : ""
                onTriggered: {
                    if (modelData.connected)
                        modelData.disconnect();
                    else
                        modelData.connect();
                }
            }
        }

        Separator {}
        MenuItem {
            text: "Bluetooth ayarları…"
            onTriggered: {
                Quickshell.execDetached(Config.settingsCommand.concat(["bluetooth"]));
                popup.visible = false;
            }
        }
    }
}
