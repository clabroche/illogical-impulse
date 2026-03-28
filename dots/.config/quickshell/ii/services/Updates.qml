pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Supports Arch via checkupdates (repos) + yay --aur (AUR).
 */
Singleton {
    id: root

    property bool available: false
    property bool useYay: false
    property bool checking: repoProc.running || aurProc.running
    property int count: repoPackages.length + aurPackages.length
    // Repo packages from checkupdates: { name, from, to }
    property var repoPackages: []
    // AUR packages from yay -Qu --aur: { name, from, to }
    property var aurPackages: []

    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        repoProc.running = true;
        if (root.useYay) aurProc.running = true;
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Process {
        id: checkYayProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["which", "yay"]
        onExited: (exitCode) => {
            root.useYay = (exitCode === 0)
            checkFallbackProc.running = true
        }
    }

    Process {
        id: checkFallbackProc
        command: ["which", "checkupdates"]
        onExited: (exitCode) => {
            root.available = (exitCode === 0)
            root.refresh()
        }
    }

    Process {
        id: repoProc
        command: ["checkupdates"]
        property var pending: []
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                if (m) repoProc.pending.push({ name: m[1], from: m[2], to: m[3] })
            }
        }
        onStarted: repoProc.pending = []
        onExited: root.repoPackages = repoProc.pending
    }

    Process {
        id: aurProc
        command: ["yay", "-Qu", "--aur"]
        property var pending: []
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                if (m) aurProc.pending.push({ name: m[1], from: m[2], to: m[3] })
            }
        }
        onStarted: aurProc.pending = []
        onExited: root.aurPackages = aurProc.pending
    }
}
