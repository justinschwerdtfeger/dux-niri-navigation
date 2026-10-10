import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Rectangle {
    id: button

    property string text: ""
    property string appId: ""
    property string faviconSource: ""
    property bool showAppIcon: false
    readonly property var desktopEntry: showAppIcon && appId ? DesktopEntries.heuristicLookup(Paths.moddedAppId(appId)) :
                                                               null
    readonly property string applicationName: showAppIcon && appId ? Paths.getAppName(appId, desktopEntry) : ""
    readonly property string iconSource: showAppIcon ? Paths.getAppIcon(appId, desktopEntry) : ""
    readonly property int appIconSize: Math.max(12, Math.floor(Math.min(height - 6, width - 8) * 0.85))
    // Favicons often fill their image bounds more densely than desktop icons.
    readonly property int faviconSize: Math.max(1, Math.floor(appIconSize * 0.85))
    property bool selected: false
    property bool urgent: false
    property string tooltip: text
    property bool acceptMiddleClick: false
    property bool dragEnabled: false
    property bool activateOnPress: false
    property bool opaqueBackground: false
    readonly property color highlightColor: selected || hovered ? Theme.withAlpha(Theme.primary, down ? 0.25 : 0.12) :
                                                                  "transparent"

    readonly property bool hovered: pointer.containsMouse
    readonly property bool down: pointer.pressed
    activeFocusOnTab: enabled
    Accessible.name: tooltip
    Accessible.role: Accessible.Button
    Accessible.focusable: true
    Accessible.onPressAction: {
        if (button.enabled) {
            button.dismissTooltip();
            button.clicked();
        }
    }
    opacity: enabled ? 1 : 0.4
    Keys.onPressed: event => {
        if (button.enabled && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            button.dismissTooltip();
            button.clicked();
            event.accepted = true;
        }
    }
    radius: Math.min(Theme.cornerRadius, height / 2)
    color: opaqueBackground ? Theme.withAlpha(Theme.surfaceContainerHigh, 1) : highlightColor
    border.width: urgent ? 1 : 0
    border.color: Theme.primary

    // Keep focus feedback inside the clipped bar, using DMS theme colors.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, button.radius - 2)
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: button.activeFocus
    }

    Rectangle {
        anchors.fill: parent
        radius: button.radius
        visible: button.opaqueBackground
        color: button.highlightColor
    }

    signal clicked
    signal middleClicked
    signal pressStarted(var anchor)
    signal pressEnded(var anchor)
    signal tabDragStarted(var anchor, real sceneX, real sceneY)
    signal tabDragMoved(var anchor, real sceneX, real sceneY)
    signal tabDragFinished(var anchor, real sceneX, real sceneY)
    signal tabDragCanceled(var anchor)
    signal tooltipRequested(var anchor)
    signal tooltipDismissed(var anchor)

    function dismissTooltip() {
        hoverDelay.stop();
        tooltipDismissed(button);
    }

    onEnabledChanged: {
        if (!enabled) {
            dismissTooltip();
            pointer.cancelTabDrag();
        }
    }
    onVisibleChanged: {
        if (!visible) {
            dismissTooltip();
            pointer.cancelTabDrag();
        }
    }
    onDragEnabledChanged: {
        if (!dragEnabled)
            pointer.cancelTabDrag();
    }
    onTooltipChanged: {
        if (hovered && enabled && !hoverDelay.running && !down)
            tooltipRequested(button);
    }
    Component.onDestruction: {
        pressEnded(button);
        tooltipDismissed(button);
        if (pointer.draggingTab)
            tabDragCanceled(button);
    }

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
            visible: button.showAppIcon && favicon.status !== Image.Ready && status === Image.Ready
            width: button.appIconSize
            height: button.appIconSize
            source: button.iconSource
            asynchronous: true
            mipmap: true
            backer.sourceSize: Qt.size(button.appIconSize * 2, button.appIconSize * 2)
        }

        Image {
            id: favicon
            anchors.centerIn: parent
            // A small optical correction for dense favicon artwork beside text.
            anchors.verticalCenterOffset: 1
            visible: button.showAppIcon && status === Image.Ready
            width: button.faviconSize
            height: button.faviconSize
            source: button.showAppIcon ? button.faviconSource : ""
            sourceSize: Qt.size(button.faviconSize * 2, button.faviconSize * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true
        }

        DankIcon {
            anchors.centerIn: parent
            visible: button.showAppIcon && favicon.status !== Image.Ready && appIcon.status !== Image.Ready
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
        acceptedButtons: Qt.LeftButton | (button.acceptMiddleClick ? Qt.MiddleButton : Qt.NoButton)
        // Tab dragging takes priority over Flickable's overflow gesture.
        preventStealing: button.dragEnabled
        cursorShape: draggingTab ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property bool draggingTab: false
        property bool draggedTab: false
        property real pressSceneX: 0
        property real pressSceneY: 0
        function cancelTabDrag() {
            if (draggingTab)
                button.tabDragCanceled(button);
            draggingTab = false;
        }
        onEntered: hoverDelay.restart()
        onExited: button.dismissTooltip()
        onPressed: mouse => {
            button.dismissTooltip();
            draggedTab = false;
            const pos = mapToItem(null, mouse.x, mouse.y);
            pressSceneX = pos.x;
            pressSceneY = pos.y;
            if (mouse.button === Qt.LeftButton) {
                button.pressStarted(button);
                if (button.activateOnPress)
                    button.clicked();
            }
        }
        onPositionChanged: mouse => {
            if (!button.dragEnabled || (pressedButtons & Qt.LeftButton) === 0)
                return;
            const pos = mapToItem(null, mouse.x, mouse.y);
            // Qt 6.11 exposes styleHints as QObject in tooling, without its properties.
            // qmllint disable missing-property
            const threshold = Qt.styleHints.startDragDistance;
            // qmllint enable missing-property
            if (!draggingTab && Math.abs(pos.x - pressSceneX) >= threshold) {
                draggedTab = true;
                draggingTab = true;
                button.dismissTooltip();
                button.tabDragStarted(button, pressSceneX, pressSceneY);
            }
            if (draggingTab)
                button.tabDragMoved(button, pos.x, pos.y);
        }
        onReleased: mouse => {
            if (draggingTab) {
                const pos = mapToItem(null, mouse.x, mouse.y);
                draggingTab = false;
                button.tabDragFinished(button, pos.x, pos.y);
            }
            if (mouse.button === Qt.LeftButton)
                button.pressEnded(button);
        }
        onCanceled: {
            cancelTabDrag();
            button.pressEnded(button);
        }
        onClicked: mouse => {
            if (draggedTab)
                return;
            if (mouse.button === Qt.MiddleButton)
                button.middleClicked();
            else if (mouse.button === Qt.LeftButton && !button.activateOnPress)
                button.clicked();
        }
    }

    Timer {
        id: hoverDelay
        interval: 500
        onTriggered: {
            if (button.hovered && button.enabled && !button.down && button.tooltip.length > 0)
                button.tooltipRequested(button);
        }
    }
}
