import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: col.implicitWidth + 8
    implicitHeight: Appearance.sizes.barHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 0

        RowLayout {
            spacing: 2

            StyledText {
                text: "↓"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                text: ResourceUsage.netSpeedString(ResourceUsage.netDownSpeed)
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            spacing: 2

            StyledText {
                text: "↑"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                text: ResourceUsage.netSpeedString(ResourceUsage.netUpSpeed)
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
