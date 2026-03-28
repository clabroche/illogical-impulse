import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property Item anchorItem
    property bool show: false
    property var closeAction: null

    // ── Persistent state (survives popup close/reopen) ─────────────────────────
    property string popupState: "idle" // idle | repo | aur | done | error | stopped
    property string logText: ""
    property real progress: 0
    property int exitCode: 0

    readonly property string askpassPath: FileUtils.trimFileProtocol(Directories.scriptPath + "/askpass.sh")
    readonly property int popupWidth: (popupState === "idle") ? 360 : 600

    // ── Phase 1 : dépôts officiels (pacman -Syu) ───────────────────────────────
    Process {
        id: repoUpdateProc
        command: ["bash", "-c",
            "export SUDO_ASKPASS='" + root.askpassPath + "'; sudo -A pacman -Syu --noconfirm 2>&1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "") return
                root.logText += line + "\n"
                const m = line.match(/^\((\d+)\/(\d+)\)/)
                if (m) root.progress = parseInt(m[1]) / parseInt(m[2])
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.exitCode = code
                root.popupState = "error"
                return
            }
            // Phase 1 done — start AUR if needed
            if (Updates.useYay && Updates.aurPackages.length > 0) {
                root.logText += "\n── AUR ──\n"
                root.progress = 0
                root.popupState = "aur"
                aurUpdateProc.running = true
            } else {
                root.popupState = "done"
            }
        }
    }

    // ── Phase 2 : AUR (yay -Sua) ───────────────────────────────────────────────
    Process {
        id: aurUpdateProc
        command: ["bash", "-c",
            "export SUDO_ASKPASS='" + root.askpassPath + "'; yay -Sua --noconfirm 2>&1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "") return
                root.logText += line + "\n"
                const m = line.match(/^\((\d+)\/(\d+)\)/)
                if (m) root.progress = parseInt(m[1]) / parseInt(m[2])
            }
        }
        onExited: (code) => {
            root.exitCode = code
            root.popupState = (code === 0) ? "done" : "error"
        }
    }

    function stopUpdate() {
        if (repoUpdateProc.running) {
            repoUpdateProc.running = false
        } else if (aurUpdateProc.running) {
            aurUpdateProc.running = false
        } else {
            return
        }
        root.logText += "\n— Annulé —\n"
        root.popupState = "stopped"
        root.exitCode = -1
    }

    function resetToIdle() {
        root.popupState = "idle"
        root.logText = ""
        root.progress = 0
        root.exitCode = 0
    }

    Timer {
        id: closeAfterStart
        interval: 100
        onTriggered: { if (root.closeAction) root.closeAction() }
    }

    function startUpdate() {
        logText = ""
        progress = 0
        popupState = "repo"
        repoUpdateProc.running = true
        closeAfterStart.start()
    }

    LazyLoader {
        id: popupLoader
        active: root.show

        component: PanelWindow {
            id: popupWindow
            color: "transparent"

            anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
            anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
            anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
            anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

            implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animationCurves.standardDecel
                }
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animationCurves.standardDecel
                }
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            margins {
                left: {
                    if (!Config.options.bar.vertical) return root.QsWindow?.mapFromItem(
                        root.anchorItem,
                        (root.anchorItem.width - popupBackground.implicitWidth) / 2, 0
                    ).x;
                    return Appearance.sizes.verticalBarWidth
                }
                top: {
                    if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                    return root.QsWindow?.mapFromItem(
                        root.anchorItem,
                        (root.anchorItem.height - popupBackground.implicitHeight) / 2, 0
                    ).y;
                }
                right: Appearance.sizes.verticalBarWidth
                bottom: Appearance.sizes.barHeight
            }

            mask: Region { item: popupBackground }
            WlrLayershell.namespace: "quickshell:popup"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // ── Shadow ─────────────────────────────────────────────────────────────
            StyledRectangularShadow { target: popupBackground }

            // ── Background container ───────────────────────────────────────────────
            Rectangle {
                id: popupBackground
                readonly property real margin: 14
                clip: true

                anchors {
                    fill: parent
                    leftMargin: Appearance.sizes.elevationMargin
                    rightMargin: Appearance.sizes.elevationMargin
                    topMargin: Appearance.sizes.elevationMargin
                    bottomMargin: Appearance.sizes.elevationMargin
                }

                implicitWidth: root.popupWidth + margin * 2
                implicitHeight: popupContent.height + margin * 2

                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.small
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                // ── Content ──────────────────────────────────────────────────────────
                ColumnLayout {
                    id: popupContent
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: popupBackground.margin
                    }
                    spacing: 10

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            fill: root.popupState === "done" ? 1 : 0
                            text: root.popupState === "done" ? "check_circle"
                                : (root.popupState === "error" || root.popupState === "stopped") ? "error"
                                : "system_update_alt"
                            iconSize: Appearance.font.pixelSize.large
                            color: root.popupState === "done" ? Appearance.colors.colTertiary
                                : (root.popupState === "error" || root.popupState === "stopped") ? Appearance.colors.colError
                                : Appearance.colors.colOnSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.popupState === "done" ? Translation.tr("Mise à jour terminée")
                                : root.popupState === "stopped" ? Translation.tr("Mise à jour annulée")
                                : root.popupState === "error" ? Translation.tr("Erreur (code %1)").arg(root.exitCode)
                                : root.popupState === "repo" ? Translation.tr("Dépôts (1/2)…")
                                : root.popupState === "aur" ? Translation.tr("AUR (2/2)…")
                                : Translation.tr("Mises à jour disponibles")
                            font {
                                weight: Font.DemiBold
                                pixelSize: Appearance.font.pixelSize.normal
                            }
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        // Update count badge (idle only)
                        Rectangle {
                            visible: root.popupState === "idle"
                            implicitWidth: Math.max(cntLabel.implicitWidth + 10, 24)
                            implicitHeight: 24
                            radius: height / 2
                            color: Updates.updateStronglyAdvised
                                ? Appearance.colors.colError
                                : Appearance.colors.colTertiary

                            StyledText {
                                id: cntLabel
                                anchors.centerIn: parent
                                text: Updates.count + " " + Translation.tr("paquets")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Updates.updateStronglyAdvised
                                    ? Appearance.m3colors.m3onError
                                    : Appearance.m3colors.m3onTertiary
                            }
                        }

                        // Stop button (running) / Close button (idle/done/error)
                        CircleUtilButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            onClicked: {
                                if (root.popupState === "repo" || root.popupState === "aur") {
                                    root.stopUpdate()
                                } else {
                                    if (root.closeAction) root.closeAction()
                                }
                            }
                            MaterialSymbol {
                                horizontalAlignment: Qt.AlignHCenter
                                readonly property bool isRunning: root.popupState === "repo" || root.popupState === "aur"
                                text: isRunning ? "stop_circle" : "close"
                                iconSize: Appearance.font.pixelSize.normal
                                color: isRunning ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                            }
                        }
                    }

                    // ── Separator ────────────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colOutlineVariant
                    }

                    // ── IDLE: package list + launch button ───────────────────────────
                    Loader {
                        active: root.popupState === "idle"
                        visible: active
                        Layout.fillWidth: true
                        sourceComponent: ColumnLayout {
                            spacing: 8
                            implicitWidth: root.popupWidth

                            // ── Reusable collapsible package section ─────────────────────
                            component PkgSection: ColumnLayout {
                                id: section
                                required property string label
                                required property var packages
                                property bool expanded: false
                                Layout.fillWidth: true
                                spacing: 0
                                visible: packages.length > 0

                                RippleButton {
                                    Layout.fillWidth: true
                                    buttonRadius: Appearance.rounding.small
                                    onClicked: section.expanded = !section.expanded

                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        MaterialSymbol {
                                            text: section.expanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: section.label
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                        }
                                        Rectangle {
                                            implicitWidth: Math.max(badgeCount.implicitWidth + 8, 20)
                                            implicitHeight: 20
                                            radius: height / 2
                                            color: Appearance.colors.colLayer0
                                            StyledText {
                                                id: badgeCount
                                                anchors.centerIn: parent
                                                text: section.packages.length
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: section.expanded ? Math.min(listView.contentHeight + 2, 180) : 0
                                    clip: true
                                    color: Appearance.colors.colLayer1
                                    radius: Appearance.rounding.small


                                    ListView {
                                        id: listView
                                        anchors { fill: parent; margins: 1 }
                                        clip: true
                                        model: section.packages
                                        spacing: 0
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: listView.width
                                            implicitHeight: pkgRow.implicitHeight + 10
                                            color: index % 2 === 0
                                                ? "transparent"
                                                : Qt.rgba(
                                                    Appearance.colors.colLayer0.r,
                                                    Appearance.colors.colLayer0.g,
                                                    Appearance.colors.colLayer0.b,
                                                    0.4)

                                            RowLayout {
                                                id: pkgRow
                                                anchors {
                                                    left: parent.left; right: parent.right
                                                    verticalCenter: parent.verticalCenter
                                                    leftMargin: 10; rightMargin: 10
                                                }
                                                spacing: 6

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colOnLayer1
                                                    elide: Text.ElideRight
                                                }
                                                StyledText {
                                                    text: modelData.from
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colSubtext
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 90
                                                }
                                                MaterialSymbol {
                                                    text: "arrow_forward"
                                                    iconSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colSubtext
                                                }
                                                StyledText {
                                                    text: modelData.to
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colTertiary
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 90
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            PkgSection {
                                label: Translation.tr("Dépôts officiels (%1)").arg(Updates.repoPackages.length)
                                packages: Updates.repoPackages
                            }

                            PkgSection {
                                visible: Updates.useYay && Updates.aurPackages.length > 0
                                label: Translation.tr("AUR (%1)").arg(Updates.aurPackages.length)
                                packages: Updates.aurPackages
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                buttonText: Translation.tr("Mettre à jour")
                                colBackground: Appearance.colors.colTertiary
                                colBackgroundHover: Appearance.colors.colTertiaryHover ?? Appearance.colors.colTertiary
                                colRipple: Appearance.colors.colTertiaryActive ?? Appearance.colors.colTertiary
                                contentItem: StyledText {
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Translation.tr("Mettre à jour")
                                    color: Appearance.m3colors.m3onTertiary
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                                onClicked: root.startUpdate()
                            }
                        }
                    }

                    // ── RUNNING: logs + progress ──────────────────────────────────────
                    Loader {
                        active: root.popupState !== "idle"
                        visible: active
                        Layout.fillWidth: true
                        sourceComponent: ColumnLayout {
                            spacing: 8
                            implicitWidth: root.popupWidth

                            // Progress bar (only during running)
                            Loader {
                                active: root.popupState === "repo" || root.popupState === "aur"
                                visible: active
                                Layout.fillWidth: true
                                sourceComponent: ColumnLayout {
                                    spacing: 4
                                    implicitWidth: root.popupWidth

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            text: root.progress > 0
                                                ? Translation.tr("Progression : %1%").arg(Math.round(root.progress * 100))
                                                : Translation.tr("Préparation…")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 6
                                        radius: height / 2
                                        color: Appearance.colors.colLayer1

                                        Rectangle {
                                            width: parent.width * root.progress
                                            height: parent.height
                                            radius: parent.radius
                                            color: Appearance.colors.colTertiary

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Appearance.animation.elementMoveFast.duration
                                                    easing.type: Appearance.animation.elementMoveFast.type
                                                }
                                            }
                                        }

                                        // Indeterminate animation when progress = 0
                                        Rectangle {
                                            visible: root.progress === 0
                                            width: parent.width * 0.3
                                            height: parent.height
                                            radius: parent.radius
                                            color: Appearance.colors.colTertiary

                                            SequentialAnimation on x {
                                                running: root.progress === 0 && (root.popupState === "repo" || root.popupState === "aur")
                                                loops: Animation.Infinite
                                                NumberAnimation {
                                                    from: -parent.width * 0.3
                                                    to: parent.parent.width
                                                    duration: 1400
                                                    easing.type: Easing.InOutSine
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Log area
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 450
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small

                                Flickable {
                                    id: logFlickable
                                    anchors {
                                        fill: parent
                                        margins: 8
                                        bottomMargin: 20
                                    }
                                    clip: true
                                    flickableDirection: Flickable.HorizontalAndVerticalFlick
                                    contentWidth: logLabel.implicitWidth
                                    contentHeight: logLabel.implicitHeight

                                    onContentHeightChanged: {
                                        if (atYEnd || root.popupState === "repo" || root.popupState === "aur")
                                            Qt.callLater(() => contentY = Math.max(0, contentHeight - height))
                                    }

                                    Text {
                                        id: logLabel
                                        text: root.logText
                                        wrapMode: Text.NoWrap
                                        font {
                                            family: Appearance.font.family.monospace ?? Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.small
                                        }
                                        color: Appearance.colors.colOnLayer1
                                    }

                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                                }
                            }

                            // Done / Error / Stopped buttons
                            Loader {
                                active: root.popupState === "done" || root.popupState === "error" || root.popupState === "stopped"
                                visible: active
                                Layout.fillWidth: true
                                sourceComponent: RowLayout {
                                    spacing: 8

                                    // "Retour" only when stopped or error (not done)
                                    RippleButton {
                                        visible: root.popupState === "stopped" || root.popupState === "error"
                                        Layout.fillWidth: true
                                        onClicked: root.resetToIdle()
                                        contentItem: StyledText {
                                            horizontalAlignment: Text.AlignHCenter
                                            text: Translation.tr("Retour")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }

                                    RippleButton {
                                        Layout.fillWidth: true
                                        onClicked: { if (root.closeAction) root.closeAction() }
                                        contentItem: StyledText {
                                            horizontalAlignment: Text.AlignHCenter
                                            text: Translation.tr("Fermer")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
