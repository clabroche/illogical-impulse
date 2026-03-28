pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string trackId: ""
    property bool fetching: false
    property bool found: false
    property string plainLyrics: ""
    property list<var> lines: []      // [{time, duration, text}]
    property int currentIndex: -1
    property real currentPosition: 0
    property int currentWordIndex: 0

    readonly property string deezerArl: KeyringStorage.keyringData?.deezer?.arl ?? ""
    readonly property bool hasDeezer: deezerArl.length > 0

    function fetchForTrack(title, artist, uniqueId) {
        if (uniqueId === root.trackId) return
        root.trackId = uniqueId
        root.found = false
        root.plainLyrics = ""
        root.lines = []
        root.currentIndex = -1
        root.currentWordIndex = 0
        if (!title || title.length === 0) return

        root.fetching = true
        if (root.hasDeezer) {
            deezerProc.pendingTitle = title
            deezerProc.pendingArtist = artist
            deezerProc.exec([
                Directories.scriptPath + "/deezer_lyrics.sh",
                root.deezerArl, title, artist
            ])
        } else {
            lrclibProc.exec([
                "curl", "-s", "-G",
                "https://lrclib.net/api/get",
                "--data-urlencode", `track_name=${title}`,
                "--data-urlencode", `artist_name=${artist}`
            ])
        }
    }

    function parseLrc(lrc) {
        const result = []
        const re = /\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/
        for (const line of lrc.split("\n")) {
            const m = line.match(re)
            if (!m) continue
            const secs = parseInt(m[1]) * 60 + parseInt(m[2]) + parseInt(m[3]) / (m[3].length === 3 ? 1000 : 100)
            result.push({ time: secs, duration: 0, text: m[4].trim() })
        }
        // Fill duration from next line's time
        for (let i = 0; i < result.length - 1; i++)
            result[i].duration = result[i + 1].time - result[i].time
        return result
    }

    function updateCurrentIndex(position) {
        if (root.lines.length === 0) return
        root.currentPosition = position
        let idx = 0
        for (let i = 0; i < root.lines.length; i++) {
            if (root.lines[i].time <= position) idx = i
            else break
        }
        if (idx !== root.currentIndex) {
            root.currentIndex = idx
            root.currentWordIndex = 0
        }

        const line = root.lines[idx]
        if (!line) return
        // Use real word timestamps if available (Deezer GraphQL)
        if (line.words && line.words.length > 0) {
            let wordIdx = 0
            for (let w = 0; w < line.words.length; w++) {
                if (line.words[w].start <= position) wordIdx = w
                else break
            }
            root.currentWordIndex = wordIdx
        } else if (line.duration > 0) {
            // Fallback: interpolation for lrclib
            const elapsed = position - line.time
            const words = line.text.trim().split(/\s+/)
            root.currentWordIndex = Math.min(
                Math.floor((elapsed / line.duration) * words.length),
                words.length - 1
            )
        }
    }

    // Deezer
    Process {
        id: deezerProc
        property string pendingTitle: ""
        property string pendingArtist: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.found && data.lines?.length > 0) {
                        root.lines = data.lines
                        root.found = true
                        root.fetching = false
                        return
                    }
                } catch(e) {}
                // Fallback to lrclib
                lrclibProc.exec([
                    "curl", "-s", "-G",
                    "https://lrclib.net/api/get",
                    "--data-urlencode", `track_name=${deezerProc.pendingTitle}`,
                    "--data-urlencode", `artist_name=${deezerProc.pendingArtist}`
                ])
            }
        }
    }

    // lrclib fallback
    Process {
        id: lrclibProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.fetching = false
                try {
                    const data = JSON.parse(text)
                    if (data.syncedLyrics?.length > 0) {
                        root.lines = root.parseLrc(data.syncedLyrics)
                        root.found = root.lines.length > 0
                    } else if (data.plainLyrics?.length > 0) {
                        root.plainLyrics = data.plainLyrics
                        root.found = true
                    }
                } catch(e) {}
            }
        }
    }
}
