pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.DCommon.Widgets
import "WorkspaceModel.js" as WorkspaceModel

Column {
    id: menu
    property string currentIcon: "empty_dashboard"
    property var pinnedIcons: []
    property string workspaceLabel: "Workspace"
    signal iconSelected(string icon)
    signal pinToggled(string icon)
    spacing: Theme.spacingS
    StyledText {
        width: menu.width
        text: menu.workspaceLabel + " icon"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
    }
    DTextField {
        id: search
        width: menu.width
        placeholderText: "Search icons"
        leftIconName: "search"
        showClearButton: true
    }
    StyledText {
        visible: menu.pinnedIcons.length > 0
        text: "Pinned"
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
    GridView {
        width: menu.width
        height: Math.min(88, Math.ceil(menu.pinnedIcons.length / Math.max(1, Math.floor(width / 44))) * 44)
        visible: menu.pinnedIcons.length > 0
        clip: true
        cellWidth: 44
        cellHeight: 44
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: DScrollbar {}
        model: menu.pinnedIcons
        delegate: WorkspaceButton {
            required property string modelData
            width: 36
            height: 36
            iconName: modelData
            label: modelData.replace(/_/g, " ")
            selected: menu.currentIcon === modelData
            onClicked: menu.iconSelected(modelData)
            onRightClicked: menu.pinToggled(modelData)
        }
    }
    StyledText {
        text: "All icons"
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
    GridView {
        width: menu.width
        height: 264
        clip: true
        cellWidth: 44
        cellHeight: 44
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: DScrollbar {}
        model: WorkspaceModel.icons.filter(icon => icon.replace(/_/g, " ").includes(search.text.toLowerCase().trim()))
        delegate: WorkspaceButton {
            required property string modelData
            width: 40
            height: 40
            iconName: modelData
            label: modelData.replace(/_/g, " ")
            selected: menu.currentIcon === modelData
            onClicked: menu.iconSelected(modelData)
            onRightClicked: menu.pinToggled(modelData)
            DIcon {
                visible: menu.pinnedIcons.includes(parent.iconName)
                anchors.right: parent.right
                anchors.top: parent.top
                name: "push_pin"
                size: 12
                color: Theme.primary
            }
        }
    }
}
