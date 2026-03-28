import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Helper function to format KB to GB
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.memoryUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.memoryFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.memoryTotal)
                }
            }
        }

        Column {
            visible: ResourceUsage.swapTotal > 0
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "swap_horiz"
                label: "Swap"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.swapUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.swapFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.swapTotal)
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                }
            }
        }

        Column {
            visible: Config.options.bar.resources.showNetworkSpeed
            anchors.top: parent.top
            spacing: 8

            readonly property real maxBytesPerSec: Config.options.bar.resources.connectionSpeedMbps * 1000 * 1000 / 8

            StyledPopupHeaderRow {
                icon: "network_node"
                label: Translation.tr("Network")
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "arrow_downward"
                    label: Translation.tr("Down:")
                    value: `${Math.round(ResourceUsage.netDownSpeed / parent.parent.maxBytesPerSec * 100)}% (${ResourceUsage.netSpeedString(ResourceUsage.netDownSpeed)})`
                }
                StyledPopupValueRow {
                    icon: "arrow_upward"
                    label: Translation.tr("Up:")
                    value: `${Math.round(ResourceUsage.netUpSpeed / parent.parent.maxBytesPerSec * 100)}% (${ResourceUsage.netSpeedString(ResourceUsage.netUpSpeed)})`
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "developer_board"
                label: "GPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.gpuUsage * 100)}%`
                }
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("VRAM:")
                    value: `${Math.round(ResourceUsage.gpuMemoryUsedPercentage * 100)}% (${ResourceUsage.gpuMemoryUsed} / ${ResourceUsage.gpuMemoryTotal} MB)`
                }
            }
        }
    }
}
