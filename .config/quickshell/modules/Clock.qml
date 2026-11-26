pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

BarButton {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Label {
        text: clock.date.toLocaleString(Qt.locale(), Config.clockFormat)
        font.pixelSize: Theme.fontSize + 1
    }

    onClicked: {
        const d = new Date();
        cal.month = d.getMonth();
        cal.year = d.getFullYear();
        cal.toggle();
    }

    Popup {
        id: cal

        property int month: 0
        property int year: 2000

        function shift(n) {
            const d = new Date(year, month + n, 1);
            month = d.getMonth();
            year = d.getFullYear();
        }

        anchorItem: root
        minWidth: 270
        padding: 10
        spacing: 6

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: clock.date.toLocaleDateString(Qt.locale(), "d MMMM yyyy, dddd")
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            BarButton {
                Icon {
                    icon: "go-previous-symbolic"
                }
                onClicked: cal.shift(-1)
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: new Date(cal.year, cal.month, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
            }
            BarButton {
                Icon {
                    icon: "go-next-symbolic"
                }
                onClicked: cal.shift(1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: Qt.locale()
            delegate: Label {
                required property string shortName
                text: shortName
                color: Theme.fgDim
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSize - 1
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 30
            month: cal.month
            year: cal.year
            locale: Qt.locale()
            spacing: 0

            delegate: Item {
                id: day
                required property var model
                implicitHeight: 30
                implicitWidth: 34

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: Theme.r(Theme.radiusXl, height)
                    color: day.model.today ? Theme.accent : "transparent"
                }
                Label {
                    anchors.centerIn: parent
                    text: day.model.day
                    opacity: day.model.month === grid.month ? 1 : 0.35
                    font.bold: day.model.today
                }
            }
        }
    }
}
