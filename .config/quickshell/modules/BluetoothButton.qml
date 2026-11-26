pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components

// COSMIC Bluetooth appleti: aç/kapat, eşleşmiş cihazlar (pil, bağlan/kes, unut),
// "Diğer cihazlar" (menü açıkken tarama, eşleştirme), PIN / kod onayı.
BarButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled_: adapter?.enabled ?? false
    readonly property var allDevices: adapter ? adapter.devices.values : []
    readonly property var paired: allDevices.filter(d => d.paired || d.connected).sort((a, b) => (b.connected - a.connected) || root.devName(a).localeCompare(root.devName(b)))
    // İsimsiz (yalnızca adresli) BLE cihazlarını gizle
    readonly property var others: allDevices.filter(d => !d.paired && !d.connected && d.deviceName !== "").sort((a, b) => root.devName(a).localeCompare(root.devName(b)))
    readonly property bool anyConnected: paired.some(d => d.connected)
    property bool showOthers: false

    function devName(d) {
        return d.name || d.deviceName || d.address;
    }

    function devIcon(d) {
        return (d.icon || "bluetooth") + "-symbolic";
    }

    function status(d) {
        if (BtAgent.pairing[d.dbusPath] || d.pairing)
            return "Eşleştiriliyor…";
        const err = BtAgent.errors[d.dbusPath];
        if (err)
            return err;
        switch (d.state) {
        case BluetoothDeviceState.Connecting:
            return "Bağlanıyor…";
        case BluetoothDeviceState.Disconnecting:
            return "Kesiliyor…";
        }
        if (d.connected)
            return d.batteryAvailable ? "Bağlı · %" + Math.round(d.battery * 100) : "Bağlı";
        return "";
    }

    visible: adapter !== null

    Icon {
        icon: !root.enabled_ ? "bluetooth-disabled-symbolic" : "bluetooth-active-symbolic"
        opacity: root.enabled_ && !root.anyConnected ? 0.6 : 1
    }

    onClicked: popup.toggle()

    // Menü açıkken yeni cihazları tara (COSMIC gibi)
    Connections {
        target: popup
        function onVisibleChanged() {
            if (root.adapter && root.enabled_)
                root.adapter.discovering = popup.visible;
            if (!popup.visible)
                root.showOthers = false;
        }
    }

    // Cihazdan gelen eşleştirme isteğinde menüyü aç
    Connections {
        target: BtAgent
        function onRequested() {
            if (!popup.visible && root.QsWindow.window?.screen === Quickshell.screens[0])
                popup.visible = true;
        }
    }

    Popup {
        id: popup
        anchorItem: root
        minWidth: 300
        maxWidth: 360

        Toggle {
            text: "Bluetooth"
            icon: "bluetooth-active-symbolic"
            checked: root.enabled_
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }

        // ---------- Eşleştirme isteği ----------
        Rectangle {
            id: prompt
            readonly property var req: BtAgent.request
            readonly property var disp: BtAgent.display
            visible: req !== null || disp !== null
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: promptCol.implicitHeight + 16
            radius: Theme.radiusS
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: promptCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    text: (prompt.req ?? prompt.disp)?.name ?? ""
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.fgDim
                    text: {
                        if (prompt.req?.kind === "confirm")
                            return "Bu kodun cihazda da göründüğünü onaylayın:";
                        if (prompt.req?.kind === "authorize")
                            return "Bu cihaz eşleşmek istiyor.";
                        if (prompt.req?.kind === "pin")
                            return "Cihazın PIN kodunu girin:";
                        if (prompt.req?.kind === "passkey")
                            return "Cihazdaki 6 haneli kodu girin:";
                        if (prompt.disp)
                            return "Cihazda bu kodu yazıp Enter'a basın:";
                        return "";
                    }
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    horizontalAlignment: Text.AlignHCenter
                    text: prompt.req?.kind === "confirm" ? prompt.req.passkey : !prompt.req && prompt.disp ? prompt.disp.code : ""
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: 4
                }

                Loader {
                    Layout.fillWidth: true
                    active: prompt.req?.kind === "pin" || prompt.req?.kind === "passkey"
                    visible: active
                    sourceComponent: PasswordField {
                        Layout.leftMargin: 0
                        Layout.rightMargin: 0
                        placeholder: prompt.req?.kind === "pin" ? "PIN" : "Kod"
                        acceptText: "Eşleştir"
                        onAccepted: text => BtAgent.accept(text)
                        onCanceled: BtAgent.reject()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: prompt.req?.kind === "confirm" || prompt.req?.kind === "authorize" || (!prompt.req && prompt.disp !== null)
                    spacing: 6
                    Item {
                        Layout.fillWidth: true
                    }
                    TextButton {
                        text: prompt.req ? "İptal" : "Kapat"
                        onClicked: {
                            if (prompt.req)
                                BtAgent.reject();
                            else
                                BtAgent.display = null;
                        }
                    }
                    TextButton {
                        visible: prompt.req !== null
                        primary: true
                        text: prompt.req?.kind === "authorize" ? "İzin ver" : "Onayla"
                        onClicked: BtAgent.accept()
                    }
                }
            }
        }

        // ---------- Eşleşmiş cihazlar ----------
        Separator {
            visible: root.enabled_ && root.paired.length > 0
        }
        Repeater {
            model: root.enabled_ ? root.paired : []

            delegate: MenuItem {
                required property BluetoothDevice modelData
                icon: root.devIcon(modelData)
                text: root.devName(modelData)
                subtitle: root.status(modelData)
                checked: modelData.connected
                actionIcon: "user-trash-symbolic"
                onActionTriggered: modelData.forget()
                onTriggered: {
                    if (modelData.connected)
                        modelData.disconnect();
                    else
                        modelData.connect();
                }
            }
        }

        // ---------- Diğer cihazlar ----------
        Separator {
            visible: root.enabled_
        }
        MenuItem {
            visible: root.enabled_
            text: "Diğer cihazlar"
            secondary: root.adapter?.discovering ? "Aranıyor…" : root.others.length > 0 ? root.others.length : ""
            trailingIcon: root.showOthers ? "go-down-symbolic" : "go-next-symbolic"
            onTriggered: root.showOthers = !root.showOthers
        }
        Repeater {
            model: root.enabled_ && root.showOthers ? root.others.slice(0, 20) : []

            delegate: MenuItem {
                required property BluetoothDevice modelData
                readonly property bool busy: BtAgent.pairing[modelData.dbusPath] || modelData.pairing
                icon: root.devIcon(modelData)
                text: root.devName(modelData)
                subtitle: root.status(modelData)
                actionIcon: busy ? "window-close-symbolic" : ""
                onActionTriggered: BtAgent.cancelPair(modelData)
                onTriggered: if (!busy)
                    BtAgent.pair(modelData)
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
