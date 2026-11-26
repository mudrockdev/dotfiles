import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// minimon benzeri: CPU %, sıcaklık, RAM, ağ ↓/↑
BarButton {
    id: root

    hPadding: 6
    onClicked: Quickshell.execDetached(Config.systemMonitorCommand)

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: SysStats.cpu.toFixed(2) + "%"
        color: Theme.cpu
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(SysStats.temp) + "°C"
        color: Theme.temp
        visible: SysStats.temp > 0
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: SysStats.memUsedGiB.toFixed(2) + " GB"
        color: Theme.mem
    }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: -2

        Label {
            text: "↓ " + SysStats.formatBits(SysStats.rxBps)
            color: Theme.netDown
            font.pixelSize: 9
            }
        Label {
            text: "↑ " + SysStats.formatBits(SysStats.txBps)
            color: Theme.netUp
            font.pixelSize: 9
            }
    }
}
