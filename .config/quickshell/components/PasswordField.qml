import QtQuick
import QtQuick.Layouts
import qs

// Satır içi parola girişi: [ alan | göster ] [Bağlan] [İptal]
ColumnLayout {
    id: root

    property string placeholder: "Password"
    property string error: ""
    property string acceptText: "Connect"
    property bool busy: false
    property alias text: input.text

    signal accepted(string text)
    signal canceled

    function focusInput() {
        input.forceActiveFocus();
    }

    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.topMargin: 2
    Layout.bottomMargin: 4
    spacing: 4

    Component.onCompleted: focusInput()

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: Theme.r(Theme.radiusS, height)
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.border

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: reveal.left
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: "white"
            font.pixelSize: Theme.fontSize
            echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
            clip: true
            onAccepted: if (text !== "")
                root.accepted(text)
            Keys.onEscapePressed: root.canceled()

            Text {
                visible: input.text === ""
                text: root.placeholder
                color: Theme.fgDim
                font: input.font
            }
        }

        Item {
            id: reveal
            property bool shown: false
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            Icon {
                anchors.centerIn: parent
                icon: reveal.shown ? "view-conceal-symbolic" : "view-reveal-symbolic"
                size: 14
                color: revealMa.containsMouse ? Theme.fg : Theme.fgDim
            }
            MouseArea {
                id: revealMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: reveal.shown = !reveal.shown
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.error !== ""
        text: root.error
        color: Theme.accent
        font.pixelSize: Theme.fontSize - 1
        wrapMode: Text.Wrap
        maximumLineCount: 3
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Item {
            Layout.fillWidth: true
        }
        TextButton {
            text: "Cancel"
            onClicked: root.canceled()
        }
        TextButton {
            text: root.busy ? "…" : root.acceptText
            primary: true
            enabled: input.text !== "" && !root.busy
            onClicked: root.accepted(input.text)
        }
    }
}
