import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.fillHeight: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            }
        }
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: 4
        anchors.fill: parent

        ClippedFilledCircularProgress {
            id: mediaCircProg
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            implicitSize: 20
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        Item {
            visible: Config.options.bar.verbose
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.rightMargin: rowLayout.spacing
            implicitHeight: marqueeText.implicitHeight
            clip: true

            readonly property bool hasLyrics: Lyrics.lines.length > 0 && Lyrics.currentIndex >= 0
            readonly property string lyricLine: hasLyrics ? (Lyrics.lines[Lyrics.currentIndex]?.text ?? "") : ""
            readonly property string fallbackText: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`

            Text {
                id: marqueeText
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family

                readonly property color colOn: Appearance.colors.colOnLayer1
                readonly property color colSub: Appearance.colors.colSubtext

                function toCss(c) {
                    return `rgb(${Math.round(c.r*255)},${Math.round(c.g*255)},${Math.round(c.b*255)})`
                }

                textFormat: parent.hasLyrics ? Text.RichText : Text.PlainText
                color: colOn
                text: {
                    if (!parent.hasLyrics) return parent.fallbackText
                    const wordIdx = Lyrics.currentWordIndex
                    const cssOn = toCss(colOn)
                    const cssSub = toCss(colSub)
                    return parent.lyricLine.split(/\s+/).map((w, i) =>
                        `<span style="color:${i <= wordIdx ? cssOn : cssSub};">${w}</span>`
                    ).join(" ")
                }

                readonly property bool needsScroll: implicitWidth > parent.width
                readonly property int wordCount: parent.hasLyrics
                    ? parent.lyricLine.split(/\s+/).length : 1

                // Quand lyrics : scroll proportionnel au mot courant
                // Sinon : centré ou x=0
                x: {
                    if (!needsScroll) return (parent.width - implicitWidth) / 2
                    if (!parent.hasLyrics) return 0
                    const wordIdx = Lyrics.currentWordIndex
                    const progress = wordCount > 1 ? wordIdx / (wordCount - 1) : 0
                    return -Math.round(progress * (implicitWidth - parent.width))
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

    }

}
