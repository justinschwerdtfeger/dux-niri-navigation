pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "SidebarModel.js" as SidebarModel

Rectangle {
    id: sidebar

    property var configuration: SidebarModel.configuration({}, 1920)
    property var windows: []
    property var faviconSources: ({})
    property var workspaceId: null
    property bool available: false
    property bool reorderBusy: false
    property var parentScreen: null
    property bool reverseScroll: false
    property bool expanded: false
    readonly property var targetGeometry: SidebarModel.geometry(configuration, expanded)
    property real animatedWidth: targetGeometry.width
    readonly property var panelGeometry: SidebarModel.geometry(configuration, expanded, animatedWidth)
    readonly property real titleOpacity: {
        if (configuration.mode === "pinned")
            return 1;
        const range = Math.max(1, configuration.width - configuration.compactWidth);
        return Math.max(0, Math.min(1, (animatedWidth - configuration.compactWidth) / range));
    }
    property bool animationReady: false
    readonly property bool expandable: configuration.mode === "expandable"
    readonly property bool stripInteractionHeld: strip.dragWindowId !== null || strip.pressedAnchor !== null
                                                 || reorderBusy
    readonly property bool interactionHeld: stripInteractionHeld || expandButton.down
    readonly property real padding: 6
    readonly property real rowHeight: 36
    property int hoverOpenDelay: 200
    property int hoverCloseDelay: 400

    signal windowActivated(var windowId)
    signal windowCloseRequested(var windowId)
    signal windowReorderRequested(var windowId, var targetId, bool after)
    signal launcherRequested
    signal columnScrollRequested(int direction)

    color: Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    implicitWidth: panelGeometry.width
    clip: true
    Component.onCompleted: animationReady = true
    Behavior on animatedWidth {
        enabled: sidebar.animationReady && sidebar.expandable && !Theme.snapListModelChanges
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    onExpandableChanged: resetExpansion()
    onConfigurationChanged: {
        if (!expandable)
            expanded = false;
        updateHover(hover.hovered);
    }

    function resetExpansion() {
        openDelay.stop();
        closeDelay.stop();
        expanded = false;
    }

    function toggleExpansion() {
        if (!expandable || interactionHeld)
            return;
        openDelay.stop();
        closeDelay.stop();
        expanded = !expanded;
    }

    function updateHover(hovered) {
        openDelay.stop();
        closeDelay.stop();
        if (!expandable || configuration.trigger !== "hover" || interactionHeld)
            return;
        if (hovered && !expanded)
            openDelay.restart();
        else if (!hovered && expanded)
            closeDelay.restart();
    }

    onInteractionHeldChanged: {
        if (interactionHeld) {
            openDelay.stop();
            closeDelay.stop();
        } else {
            updateHover(hover.hovered);
        }
    }
    Keys.onEscapePressed: event => {
        if (expandable && expanded && !interactionHeld) {
            resetExpansion();
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: sidebar.updateHover(hovered)
    }
    Timer {
        id: openDelay
        interval: sidebar.hoverOpenDelay
        onTriggered: sidebar.expanded = true
    }
    Timer {
        id: closeDelay
        interval: sidebar.hoverCloseDelay
        onTriggered: sidebar.expanded = false
    }

    NavigationButton {
        id: expandButton
        objectName: "sidebarExpandButton"
        x: sidebar.padding
        y: sidebar.padding
        width: Math.max(sidebar.rowHeight, sidebar.width - sidebar.padding * 2)
        height: sidebar.rowHeight
        visible: sidebar.expandable
        text: sidebar.panelGeometry.showTitles || sidebar.animatedWidth > sidebar.configuration.compactWidth
              ? "Collapse titles" : (sidebar.configuration.side === "left" ? "›" : "‹")
        textOpacity: sidebar.animatedWidth > sidebar.configuration.compactWidth ? sidebar.titleOpacity : 1
        tooltip: sidebar.panelGeometry.showTitles ? "Collapse window titles" : "Expand window titles"
        enabled: !sidebar.stripInteractionHeld
        onClicked: sidebar.toggleExpansion()
        onTooltipRequested: anchor => strip.showTooltip(anchor)
        onTooltipDismissed: anchor => strip.hideTooltip(anchor)
    }

    WindowStrip {
        id: strip
        objectName: "sidebarWindowStrip"
        x: sidebar.padding
        y: sidebar.padding + (sidebar.expandable ? sidebar.rowHeight + Theme.spacingXS : 0)
        vertical: true
        verticalDisplay: "titles"
        showTitles: sidebar.panelGeometry.showTitles || sidebar.animatedWidth > sidebar.configuration.compactWidth
        titleOpacity: sidebar.titleOpacity
        verticalRowHeight: sidebar.rowHeight
        tabIconSize: Math.max(12, Math.floor((sidebar.rowHeight - 8) * 0.85))
        buttonHeight: Math.max(sidebar.rowHeight, sidebar.width - sidebar.padding * 2)
        maximumWidth: Math.max(sidebar.rowHeight, sidebar.height - y - sidebar.padding)
        windows: sidebar.windows
        faviconSources: sidebar.faviconSources
        workspaceId: sidebar.workspaceId
        available: sidebar.available
        reorderBusy: sidebar.reorderBusy
        parentScreen: sidebar.parentScreen
        barEdge: sidebar.configuration.side
        barThickness: sidebar.width
        reverseScroll: sidebar.reverseScroll
        onWindowActivated: windowId => sidebar.windowActivated(windowId)
        onWindowCloseRequested: windowId => sidebar.windowCloseRequested(windowId)
        onWindowReorderRequested: (windowId, targetId, after) => sidebar.windowReorderRequested(windowId, targetId,
                                                                                                after)
        onLauncherRequested: sidebar.launcherRequested()
        onColumnScrollRequested: direction => sidebar.columnScrollRequested(direction)
    }
}
