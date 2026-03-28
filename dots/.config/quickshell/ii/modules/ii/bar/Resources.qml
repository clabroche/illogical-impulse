import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: (Config.options.bar.resources.alwaysShowSwap && percentage > 0) || 
                (MprisController.activePlayer?.trackTitle == null) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu ||
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        Resource {
            iconName: "developer_board"
            percentage: ResourceUsage.gpuUsage
            shown: Config.options.bar.resources.alwaysShowGpu ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.gpuWarningThreshold
        }

        Resource {
            readonly property real maxBytesPerSec: Config.options.bar.resources.connectionSpeedMbps * 1000 * 1000 / 8
            iconName: "arrow_downward"
            percentage: ResourceUsage.netDownSpeed / maxBytesPerSec
            shown: Config.options.bar.resources.showNetworkSpeed ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
        }

        Resource {
            readonly property real maxBytesPerSec: Config.options.bar.resources.connectionSpeedMbps * 1000 * 1000 / 8
            iconName: "arrow_upward"
            percentage: ResourceUsage.netUpSpeed / maxBytesPerSec
            shown: Config.options.bar.resources.showNetworkSpeed ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
        }

    }

    ResourcesPopup {
        hoverTarget: root
    }
}
