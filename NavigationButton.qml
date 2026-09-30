import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Rectangle {
    id: button

    property string text: ""
    property string appId: ""
    property bool showAppIcon: false
    readonly property string iconSource: showAppIcon ? Paths.getAppIcon(appId,
        DesktopEntries.heuristicLookup(Paths.moddedAppId(appId))) : ""
    readonly property int appIconSize: Math.max(12,
        Math.floor(Math.min(height - 6, width - 8)))
    property bool selected: false
    property bool urgent: false
    property string tooltip: text

    readonly property bool hovered: pointer.containsMouse
    readonly property bool down: pointer.pressed
    Accessible.name: tooltip
    Accessible.role: Accessible.Button
    Accessible.onPressAction: {
        if (button.enabled)
            button.clicked();
    }
    opacity: enabled ? 1 : 0.4
    radius: Math.min(Theme.cornerRadius, height / 2)
    color: selected || hovered
        ? Theme.withAlpha(Theme.primary, down ? 0.25 : 0.12) : "transparent"
    border.width: urgent ? 1 : 0
    border.color: Theme.primary

    signal clicked()

    // Match DMS's focused-window icon path. AppIconRenderer's "image:"
    // prefix handling conflicts with Quickshell's image://icon provider URLs.
    Item {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: button.appIconSize
        height: button.appIconSize

        IconImage {
            id: appIcon
            anchors.centerIn: parent
            visible: button.showAppIcon && status === Image.Ready
            width: button.appIconSize
            height: button.appIconSize
            source: button.iconSource
            asynchronous: true
            mipmap: true
            backer.sourceSize: Qt.size(button.appIconSize * 2, button.appIconSize * 2)
        }

        DankIcon {
            anchors.centerIn: parent
            visible: button.showAppIcon && appIcon.status !== Image.Ready
            name: "window"
            size: button.appIconSize
            color: button.selected ? Theme.primary : Theme.surfaceText
        }
    }

    StyledText {
        anchors.fill: parent
        anchors.margins: Math.min(4, button.height / 8)
        anchors.leftMargin: button.showAppIcon ? button.appIconSize + 12 : Math.min(4, button.height / 8)
        text: button.text
        textFormat: Text.PlainText
        color: button.selected ? Theme.primary : Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: button.showAppIcon ? Text.AlignLeft : Text.AlignHCenter
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    ToolTip {
        id: help
        visible: button.hovered && button.enabled && button.tooltip.length > 0
        text: button.tooltip
        delay: 500
        contentItem: StyledText {
            text: help.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
    }
}
