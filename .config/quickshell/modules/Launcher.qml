import QtQuick
import Quickshell
import qs
import qs.components

// COSMIC App Library düğmesi. Temanın logosu varsa (ör. Azur Lane) o gösterilir.
BarButton {
    hPadding: Theme.launcherLogo !== "" ? 4 : 6

    Icon {
        visible: Theme.launcherLogo === ""
        icon: Theme.launcherIcon
        fallback: "start-here-symbolic"
        colorize: Theme.launcherIconColorize
    }
    Image {
        visible: Theme.launcherLogo !== ""
        source: Theme.launcherLogo
        height: Config.barHeight - 4
        width: implicitWidth > 0 ? height * implicitWidth / implicitHeight : height
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }
    onClicked: Quickshell.execDetached(Config.launcherCommand)
}
