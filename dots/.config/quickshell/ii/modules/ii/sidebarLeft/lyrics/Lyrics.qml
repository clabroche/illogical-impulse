pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property real syncedPos: 0
    property real syncedAt: -1     // -1 = not yet synced

    function currentPos() {
        if (root.syncedAt < 0) return 0
        if (!MprisController.activePlayer?.isPlaying) return root.syncedPos
        return root.syncedPos + (Date.now() / 1000 - root.syncedAt)
    }

    // Update lyrics every 100ms
    Timer {
        interval: 100
        running: MprisController.activePlayer != null && Lyrics.lines.length > 0
        repeat: true
        onTriggered: Lyrics.updateCurrentIndex(root.currentPos())
    }

    // Sync from playerctl every 500ms
    Timer {
        interval: 500
        running: MprisController.activePlayer != null && Lyrics.lines.length > 0
        repeat: true
        onTriggered: if (!playerctlProc.running) playerctlProc.running = true
    }

    Process {
        id: playerctlProc
        command: ["playerctl", "position"]
        stdout: SplitParser {
            onRead: line => {
                const realPos = parseFloat(line.trim())
                if (!isNaN(realPos)) {
                    root.syncedPos = realPos
                    root.syncedAt = Date.now() / 1000
                }
            }
        }
    }

    Connections {
        target: MprisController
        function onActiveTrackChanged() {
            root.syncedPos = 0
            root.syncedAt = -1
            const t = MprisController.activeTrack
            Lyrics.fetchForTrack(t.title, t.artist, t.uniqueId)
        }
    }

    Component.onCompleted: {
        const t = MprisController.activeTrack
        if (t) Lyrics.fetchForTrack(t.title, t.artist, t.uniqueId)
    }

    property bool showSettings: false

    // ARL setup prompt
    Item {
        id: arlSetup
        anchors.fill: parent
        visible: (!Lyrics.hasDeezer || root.showSettings) && !Lyrics.fetching

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "music_note"
                iconSize: 32
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Lyrics.hasDeezer
                    ? Translation.tr("Change your Deezer ARL token")
                    : Translation.tr("Enter your Deezer ARL token for synced lyrics")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: Lyrics.hasDeezer
                text: Translation.tr("✓ ARL token configured")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
            TextField {
                id: arlInput
                Layout.fillWidth: true
                placeholderText: "ARL token"
                echoMode: TextInput.Password
                font.pixelSize: Appearance.font.pixelSize.small
                background: Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                }
                color: Appearance.colors.colOnLayer1
                leftPadding: 8; rightPadding: 8
                Keys.onReturnPressed: arlSetup.saveArl()
            }
            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: arlLabel.implicitWidth + 24
                implicitHeight: arlLabel.implicitHeight + 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                onPressed: arlSetup.saveArl()

                StyledText {
                    id: arlLabel
                    anchors.centerIn: parent
                    text: Translation.tr("Save")
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Translation.tr("Find it in your browser cookies on deezer.com (cookie \"arl\")")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller ?? Appearance.font.pixelSize.small
            }
        }

        function saveArl() {
            const val = arlInput.text.trim()
            if (val.length === 0) return
            KeyringStorage.setNestedField(["deezer", "arl"], val)
            arlInput.text = ""
            root.showSettings = false
            // Force re-fetch with new ARL
            Lyrics.trackId = ""
            const t = MprisController.activeTrack
            if (t) Lyrics.fetchForTrack(t.title, t.artist, t.uniqueId)
        }
    }

    // Fetching
    Item {
        anchors.fill: parent
        visible: Lyrics.fetching
        StyledText {
            anchors.centerIn: parent
            text: "..."
            color: Appearance.colors.colSubtext
        }
    }

    // No lyrics
    Item {
        anchors.fill: parent
        visible: Lyrics.hasDeezer && !Lyrics.fetching && !Lyrics.found && !root.showSettings
        StyledText {
            anchors.centerIn: parent
            text: MprisController.activePlayer ? Translation.tr("No lyrics found") : Translation.tr("Nothing playing")
            color: Appearance.colors.colSubtext
        }
    }

    // Synced lyrics
    ListView {
        id: lyricsList
        anchors.fill: parent
        clip: true
        model: Lyrics.lines
        spacing: 6
        visible: Lyrics.hasDeezer && !Lyrics.fetching && Lyrics.found && Lyrics.lines.length > 0 && !root.showSettings

        Connections {
            target: Lyrics
            function onCurrentIndexChanged() {
                lyricsList.positionViewAtIndex(Lyrics.currentIndex, ListView.Center)
            }
        }
        onCountChanged: positionViewAtIndex(Lyrics.currentIndex, ListView.Center)

        Behavior on contentY {
            NumberAnimation { duration: 600; easing.type: Easing.InOutCubic }
        }

        delegate: Item {
            id: delegateItem
            required property int index
            required property var modelData
            width: lyricsList.width
            implicitHeight: lineContent.implicitHeight + 10

            readonly property bool isCurrent: index === Lyrics.currentIndex
            readonly property int dist: Math.abs(index - Lyrics.currentIndex)
            readonly property real targetOpacity: dist === 0 ? 1.0
                : dist === 1 ? 0.55
                : dist === 2 ? 0.35
                : 0.18

            opacity: targetOpacity
            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
            }

            Text {
                id: lineContent
                anchors {
                    left: parent.left; right: parent.right
                    leftMargin: 12; rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: delegateItem.isCurrent ? Text.RichText : Text.PlainText
                font.pixelSize: delegateItem.isCurrent
                    ? Appearance.font.pixelSize.large
                    : delegateItem.dist === 1
                        ? Appearance.font.pixelSize.normal
                        : Appearance.font.pixelSize.small
                font.weight: delegateItem.isCurrent ? Font.Medium : Font.Normal
                font.family: Appearance.font.family
                color: Appearance.colors.colOnLayer1

                readonly property string plainTxt: delegateItem.modelData.text || "·"
                readonly property color colOn: Appearance.colors.colOnLayer1
                readonly property color colSub: Appearance.colors.colSubtext

                function toCss(c) {
                    return `rgb(${Math.round(c.r*255)},${Math.round(c.g*255)},${Math.round(c.b*255)})`
                }

                text: {
                    if (!delegateItem.isCurrent) return plainTxt
                    const wordIdx = Lyrics.currentWordIndex
                    const cssOn = toCss(colOn)
                    const cssSub = toCss(colSub)
                    const words = plainTxt.split(/\s+/)
                    return words.map((w, i) =>
                        `<span style="color:${i <= wordIdx ? cssOn : cssSub};">${w}</span>`
                    ).join(" ")
                }

                Behavior on font.pixelSize {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // Plain lyrics fallback
    ScrollView {
        anchors.fill: parent
        visible: Lyrics.hasDeezer && !Lyrics.fetching && Lyrics.found && Lyrics.lines.length === 0 && !root.showSettings
        clip: true
        StyledText {
            width: parent.width
            text: Lyrics.plainLyrics
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colOnLayer1
            leftPadding: 12; rightPadding: 12
        }
    }

    // Settings button — declared last to stay on top of everything
    RippleButton {
        visible: Lyrics.hasDeezer
        anchors { top: parent.top; right: parent.right; margins: 4 }
        implicitWidth: 28; implicitHeight: 28
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2
        onPressed: root.showSettings = !root.showSettings
        MaterialSymbol {
            anchors.centerIn: parent
            text: "settings"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
    }
}
