import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Uygulama menüsü (Xfce Whisker Menu benzeri):
//   üstte kullanıcı + ayarlar / kilit / oturumu kapat / kapat düğmeleri, arama kutusu,
//   solda uygulama listesi, sağda kategoriler (Favoriler, Son kullanılanlar, Tümü, ...).
// Yazmaya başlamak arar; ↑/↓ seçer, Enter başlatır, Esc temizler/kapatır.
// Sağ tık: favorilere ekle/çıkar, panele sabitle, uygulama eylemleri.
// Panel düğmesine sağ tık COSMIC App Library'yi açar.
// Temanın logosu varsa (ör. Azur Lane) düğmede o gösterilir.
BarButton {
    id: root

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
        // Boyut sabit en-boy oranından: implicitWidth'e bağlamak SVG'nin dev boyutta
        // çizilmeye çalışılmasına yol açıyordu ("requested buffer size is too big").
        height: Config.barHeight - 4
        width: Math.round(height * Theme.launcherLogoAspect)
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Quickshell.execDetached(Config.launcherCommand);
        else
            menu.toggle();
    }

    // ---------------- Veri ----------------

    readonly property var catDefs: [
        { id: "Utility", name: "Accessories", icon: "applications-accessories" },
        { id: "Development", name: "Development", icon: "applications-development" },
        { id: "Education", name: "Education", icon: "applications-education" },
        { id: "Game", name: "Games", icon: "applications-games" },
        { id: "Graphics", name: "Graphics", icon: "applications-graphics" },
        { id: "Network", name: "Internet", icon: "applications-internet" },
        { id: "AudioVideo", name: "Multimedia", icon: "applications-multimedia" },
        { id: "Office", name: "Office", icon: "applications-office" },
        { id: "Science", name: "Science", icon: "applications-science" },
        { id: "Settings", name: "Settings", icon: "preferences-desktop" },
        { id: "System", name: "System", icon: "applications-system" }
    ]

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    function lookup(id) {
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }

    function inCat(e, id) {
        const c = e.categories ?? [];
        if (id === "System")
            return c.includes("System") && !c.includes("Settings");
        if (id === "AudioVideo")
            return c.includes("AudioVideo") || c.includes("Audio") || c.includes("Video");
        return c.includes(id);
    }

    // Favoriler: ayarlanmadıysa paneldeki başlatıcılar
    readonly property var favIds: Settings.menuFavorites ?? Config.favorites
    readonly property var favEntries: favIds.map(id => lookup(id)).filter(e => e && !e.noDisplay)
    readonly property var recentEntries: (Settings.recentApps ?? []).map(id => lookup(id)).filter(e => e)

    function isFav(e) {
        return favEntries.includes(e);
    }
    function toggleFav(e) {
        if (!Settings.loaded)
            return;
        if (isFav(e))
            Settings.menuFavorites = favIds.filter(id => lookup(id) !== e);
        else
            Settings.menuFavorites = favIds.concat([e.id]);
    }
    function isPinned(e) {
        return Config.favorites.some(id => lookup(id) === e);
    }
    function togglePin(e) {
        const id = Config.favorites.find(f => lookup(f) === e);
        if (id !== undefined)
            Config.unpin(id);
        else
            Config.pin(e.id);
    }

    readonly property var categories: {
        const list = [
            { id: "favorites", name: "Favorites", icon: "emblem-favorite" },
            { id: "recent", name: "Recently Used", icon: "document-open-recent" },
            { id: "all", name: "All Applications", icon: "applications-other" }
        ];
        for (const c of catDefs)
            if (apps.some(e => inCat(e, c.id)))
                list.push(c);
        if (apps.some(e => !catDefs.some(c => inCat(e, c.id))))
            list.push({ id: "other", name: "Other", icon: "applications-other" });
        return list;
    }

    function appsFor(cat) {
        switch (cat) {
        case "favorites":
            return favEntries;
        case "recent":
            return recentEntries;
        case "all":
            return apps;
        case "other":
            return apps.filter(e => !catDefs.some(c => inCat(e, c.id)));
        default:
            return apps.filter(e => inCat(e, cat));
        }
    }

    // Her terim eşleşmeli; küçük puan = daha iyi
    function search(query) {
        const terms = query.toLowerCase().split(/\s+/).filter(t => t);
        const out = [];
        for (const e of apps) {
            const name = e.name.toLowerCase();
            const words = name.split(/[\s\-_.]+/);
            const meta = [e.genericName, (e.keywords ?? []).join(" ")].join(" ").toLowerCase();
            const extra = [e.comment, e.id, e.execString].join(" ").toLowerCase();
            let total = 0;
            for (const t of terms) {
                let s;
                if (name.startsWith(t))
                    s = 0;
                else if (words.some(w => w.startsWith(t)))
                    s = 1;
                else if (name.includes(t))
                    s = 2;
                else if (meta.includes(t))
                    s = 3;
                else if (extra.includes(t))
                    s = 4;
                else {
                    total = -1;
                    break;
                }
                total += s;
            }
            if (total >= 0)
                out.push({ e: e, s: total });
        }
        out.sort((a, b) => (a.s - b.s) || a.e.name.localeCompare(b.e.name));
        return out.map(o => o.e);
    }

    function launch(e) {
        menu.visible = false;
        e.execute();
        const recent = [e.id].concat((Settings.recentApps ?? []).filter(id => id !== e.id)).slice(0, 10);
        if (Settings.loaded)
            Settings.recentApps = recent;
    }

    function session(cmd) {
        menu.visible = false;
        Quickshell.execDetached(cmd);
    }

    // Kullanıcı adı (GECOS) ve avatar (~/.face veya AccountsService; yoksa simge)
    property string userName: Quickshell.env("USER") ?? ""
    property string avatarPath: ""
    Process {
        running: true
        command: ["sh", "-c", 'for f in "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$USER"; do [ -r "$f" ] && { echo "$f"; break; }; done']
        stdout: StdioCollector {
            onStreamFinished: root.avatarPath = text.trim()
        }
    }
    readonly property string userLogin: Quickshell.env("USER") ?? ""
    Process {
        running: true
        command: ["getent", "passwd", root.userLogin]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0].trim();
                if (gecos !== "")
                    root.userName = gecos;
            }
        }
    }

    // ---------------- Menü ----------------

    Popup {
        id: menu
        anchorItem: root
        minWidth: 640
        maxWidth: 640
        padding: 10

        property string category: "favorites"
        readonly property string query: searchInput.text.trim()
        readonly property var shown: query !== "" ? root.search(query) : root.appsFor(category)
        readonly property bool grid: Settings.menuLayout === "grid"
        readonly property var view: grid ? appGrid : appList
        readonly property int cols: Math.max(1, Math.floor(appGrid.width / appGrid.cellWidth))

        function setLayout(l) {
            if (Settings.loaded)
                Settings.menuLayout = l;
            searchInput.forceActiveFocus();
        }
        function move(delta) {
            const v = menu.view;
            if (v.count > 0)
                v.currentIndex = Math.max(0, Math.min(v.count - 1, v.currentIndex + delta));
        }

        onVisibleChanged: {
            if (visible) {
                searchInput.text = "";
                menu.category = root.favEntries.length > 0 ? "favorites" : "all";
                appList.currentIndex = 0;
                appGrid.currentIndex = 0;
                appList.positionViewAtBeginning();
                appGrid.positionViewAtBeginning();
                Qt.callLater(() => searchInput.forceActiveFocus());
            } else {
                ctx.close();
            }
        }
        onShownChanged: {
            appList.currentIndex = 0;
            appGrid.currentIndex = 0;
        }
        onGridChanged: menu.view.currentIndex = 0

        Item {
            id: body
            Layout.fillWidth: true
            implicitWidth: 620
            implicitHeight: 520

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                // --- Üst: kullanıcı + oturum düğmeleri ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        color: Qt.alpha(Theme.accent, 0.25)
                        clip: true

                        Image {
                            id: avatar
                            anchors.fill: parent
                            source: root.avatarPath !== "" ? "file://" + root.avatarPath : ""
                            sourceSize.width: 68
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !avatar.visible
                            icon: "avatar-default-symbolic"
                            size: 20
                        }
                    }
                    Label {
                        Layout.maximumWidth: 300
                        text: root.userName
                        font.bold: true
                        font.pixelSize: Theme.fontSize + 2
                        elide: Text.ElideRight
                    }
                    // Azur Lane temasında adın yanında çapa
                    Icon {
                        visible: Theme.azur
                        icon: Qt.resolvedUrl("../assets/al-anchor.svg")
                        colorize: false
                        size: 20
                    }
                    Item {
                        Layout.fillWidth: true
                    }

                    IconBtn {
                        icon: "view-list-symbolic"
                        fallback: "view-list-details-symbolic"
                        tip: "List view"
                        checked: !menu.grid
                        onClicked: menu.setLayout("list")
                    }
                    IconBtn {
                        icon: "view-grid-symbolic"
                        fallback: "view-app-grid-symbolic"
                        tip: "Grid view"
                        checked: menu.grid
                        onClicked: menu.setLayout("grid")
                    }
                    Rectangle {
                        implicitWidth: 1
                        implicitHeight: 18
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        color: Theme.separator
                    }
                    IconBtn {
                        icon: "preferences-system-symbolic"
                        tip: "All Settings"
                        onClicked: root.session(Config.settingsCommand)
                    }
                    IconBtn {
                        icon: "system-lock-screen-symbolic"
                        tip: "Lock Screen"
                        onClicked: root.session(Config.powerCommands.lock)
                    }
                    IconBtn {
                        icon: "system-log-out-symbolic"
                        tip: "Log Out"
                        onClicked: root.session(Config.powerCommands.logout)
                    }
                    IconBtn {
                        icon: "system-shutdown-symbolic"
                        tip: "Shut Down"
                        onClicked: root.session(Config.powerCommands.shutdown)
                    }
                }

                // --- Arama ---
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Theme.r(Theme.radiusS, height)
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.border

                    Icon {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "system-search-symbolic"
                        color: Theme.fgDim
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: searchIcon.right
                        anchors.right: clearBtn.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: "white"
                        font.pixelSize: Theme.fontSize + 1
                        clip: true

                        Text {
                            visible: searchInput.text === ""
                            text: "Search applications…"
                            color: Theme.fgDim
                            font: searchInput.font
                        }

                        Keys.onPressed: event => {
                            const n = menu.view.count;
                            const step = menu.grid ? menu.cols : 1;
                            switch (event.key) {
                            case Qt.Key_Down:
                                menu.move(step);
                                break;
                            case Qt.Key_Up:
                                menu.move(-step);
                                break;
                            case Qt.Key_Right:
                            case Qt.Key_Left:
                                // Izgarada ←/→ yalnızca arama kutusu boşken gezinir
                                if (!menu.grid || searchInput.text !== "")
                                    return;
                                menu.move(event.key === Qt.Key_Right ? 1 : -1);
                                break;
                            case Qt.Key_PageDown:
                                menu.move(step * (menu.grid ? 4 : 10));
                                break;
                            case Qt.Key_PageUp:
                                menu.move(-step * (menu.grid ? 4 : 10));
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                if (n > 0)
                                    root.launch(menu.shown[Math.max(0, menu.view.currentIndex)]);
                                break;
                            case Qt.Key_Escape:
                                if (ctx.visible)
                                    ctx.close();
                                else if (searchInput.text !== "")
                                    searchInput.text = "";
                                else
                                    menu.visible = false;
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                    IconBtn {
                        id: clearBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        visible: searchInput.text !== ""
                        icon: "edit-clear-symbolic"
                        onClicked: searchInput.text = ""
                    }
                }

                // --- Uygulamalar | kategoriler ---
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: appList
                            anchors.fill: parent
                            visible: !menu.grid
                            clip: true
                            model: menu.shown
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0
                            currentIndex: 0

                            delegate: Rectangle {
                                id: appRow
                                required property var modelData
                                required property int index
                                readonly property bool current: ListView.isCurrentItem

                                width: ListView.view.width
                                height: 42
                                radius: Theme.radius
                                color: appMa.pressed ? Theme.pressed : current ? Theme.hover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Icon {
                                        size: 28
                                        colorize: false
                                        icon: appRow.modelData.icon
                                        fallback: "application-x-executable"
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label {
                                            Layout.fillWidth: true
                                            text: appRow.modelData.name
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            readonly property string desc: appRow.modelData.comment || appRow.modelData.genericName || ""
                                            visible: desc !== ""
                                            text: desc
                                            color: Theme.fgDim
                                            font.pixelSize: Theme.fontSize - 1
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Icon {
                                        visible: menu.category !== "favorites" && root.isFav(appRow.modelData)
                                        icon: "starred-symbolic"
                                        size: 12
                                        color: Theme.fgDim
                                    }
                                }

                                MouseArea {
                                    id: appMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPositionChanged: appList.currentIndex = appRow.index
                                    onEntered: appList.currentIndex = appRow.index
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            const p = mapToItem(body, mouse.x, mouse.y);
                                            ctx.show(appRow.modelData, p.x, p.y);
                                        } else {
                                            root.launch(appRow.modelData);
                                        }
                                    }
                                }
                            }
                        }

                        // Izgara görünümü
                        GridView {
                            id: appGrid
                            anchors.fill: parent
                            visible: menu.grid
                            clip: true
                            model: menu.shown
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0
                            currentIndex: 0
                            // Sütunlar genişliği tam doldursun
                            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 104)))
                            cellHeight: 92

                            delegate: Item {
                                id: cell
                                required property var modelData
                                required property int index
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: Theme.radius
                                    color: cellMa.pressed ? Theme.pressed : cell.GridView.isCurrentItem ? Theme.hover : "transparent"

                                    Icon {
                                        id: cellIcon
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 10
                                        size: 40
                                        colorize: false
                                        icon: cell.modelData.icon
                                        fallback: "application-x-executable"
                                    }
                                    Icon {
                                        visible: menu.category !== "favorites" && root.isFav(cell.modelData)
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 5
                                        icon: "starred-symbolic"
                                        size: 10
                                        color: Theme.fgDim
                                    }
                                    Label {
                                        anchors.top: cellIcon.bottom
                                        anchors.topMargin: 6
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        horizontalAlignment: Text.AlignHCenter
                                        text: cell.modelData.name
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                }

                                MouseArea {
                                    id: cellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPositionChanged: appGrid.currentIndex = cell.index
                                    onEntered: appGrid.currentIndex = cell.index
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            const p = mapToItem(body, mouse.x, mouse.y);
                                            ctx.show(cell.modelData, p.x, p.y);
                                        } else {
                                            root.launch(cell.modelData);
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: menu.shown.length === 0
                            color: Theme.fgDim
                            text: menu.query !== "" ? "No applications found" : menu.category === "favorites" ? "Right-click an application to add it to favorites" : menu.category === "recent" ? "No recently used applications" : "No applications"
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        implicitWidth: 1
                        color: Theme.separator
                    }

                    // Kategoriler (üzerine gelince kısa gecikmeyle geçer)
                    ListView {
                        id: catList
                        Layout.fillHeight: true
                        Layout.preferredWidth: 180
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.categories
                        spacing: 1

                        Timer {
                            id: hoverSwitch
                            property string target: ""
                            interval: 140
                            onTriggered: menu.selectCategory(target)
                        }

                        delegate: Rectangle {
                            id: catRow
                            required property var modelData
                            readonly property bool selected: menu.query === "" && menu.category === modelData.id

                            width: ListView.view.width
                            height: 32
                            radius: Theme.radius
                            color: selected ? Qt.alpha(Theme.accent, 0.30) : catMa.containsMouse ? Theme.hover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Icon {
                                    size: 20
                                    colorize: false
                                    icon: catRow.modelData.icon
                                    fallback: "applications-other"
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: catRow.modelData.name
                                    font.bold: catRow.selected
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: catMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    hoverSwitch.target = catRow.modelData.id;
                                    hoverSwitch.restart();
                                }
                                onExited: if (hoverSwitch.target === catRow.modelData.id)
                                    hoverSwitch.stop()
                                onClicked: {
                                    hoverSwitch.stop();
                                    menu.selectCategory(catRow.modelData.id);
                                }
                            }
                        }
                    }
                }
            }

            // --- Sağ tık menüsü (menünün içinde) ---
            MouseArea {
                anchors.fill: parent
                visible: ctx.visible
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: ctx.close()
            }
            Rectangle {
                id: ctx
                property var entry: null
                visible: false
                z: 10
                width: 220
                height: ctxCol.implicitHeight + 12
                radius: Theme.radiusS
                color: Theme.popupBg
                border.color: Theme.border
                border.width: 1

                function show(e, px, py) {
                    entry = e;
                    x = Math.min(px, body.width - width);
                    visible = true;
                    y = Math.max(0, Math.min(py, body.height - height));
                }
                function close() {
                    visible = false;
                    entry = null;
                    searchInput.forceActiveFocus();
                }

                ColumnLayout {
                    id: ctxCol
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 0

                    MenuItem {
                        text: "Launch"
                        icon: "media-playback-start-symbolic"
                        onTriggered: root.launch(ctx.entry)
                    }
                    Repeater {
                        model: ctx.entry?.actions ?? []
                        delegate: MenuItem {
                            required property var modelData
                            text: modelData.name
                            onTriggered: {
                                menu.visible = false;
                                modelData.execute();
                            }
                        }
                    }
                    Separator {}
                    MenuItem {
                        readonly property bool fav: ctx.entry ? root.isFav(ctx.entry) : false
                        text: fav ? "Remove from Favorites" : "Add to Favorites"
                        icon: fav ? "non-starred-symbolic" : "starred-symbolic"
                        onTriggered: {
                            root.toggleFav(ctx.entry);
                            ctx.close();
                        }
                    }
                    MenuItem {
                        readonly property bool pinned: ctx.entry ? root.isPinned(ctx.entry) : false
                        text: pinned ? "Unpin from Panel" : "Pin to Panel"
                        icon: "view-pin-symbolic"
                        onTriggered: {
                            root.togglePin(ctx.entry);
                            ctx.close();
                        }
                    }
                }
            }
        }

        function selectCategory(id) {
            if (menu.category === id && searchInput.text === "")
                return;
            searchInput.text = "";
            menu.category = id;
            appList.positionViewAtBeginning();
            appGrid.positionViewAtBeginning();
        }
    }

    // Küçük yuvarlak ikon düğmesi
    component IconBtn: Rectangle {
        id: btn
        property string icon: ""
        property string tip: ""
        property string fallback: "image-missing"
        property bool checked: false
        property int size: 30
        signal clicked

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: btnMa.pressed ? Theme.pressed : btn.checked ? Qt.alpha(Theme.accent, 0.30) : btnMa.containsMouse ? Theme.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            icon: btn.icon
            fallback: btn.fallback
            color: btn.checked ? Theme.accent : Theme.fg
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
