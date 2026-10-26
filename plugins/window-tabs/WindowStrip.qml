pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import "WindowModel.js" as WindowModel
import "ModelUtils.js" as ModelUtils

Item {
    id: strip

    property var windows: []
    property var faviconSources: ({})
    property var workspaceId: null
    property bool available: false
    property bool reorderBusy: false
    property bool vertical: false
    property string verticalDisplay: "icons"
    property bool showTitles: !vertical || verticalDisplay !== "icons"
    property real titleOpacity: 1
    // Standalone sidebars keep row/icon geometry independent of panel width.
    // Zero retains ordinary bar sizing.
    property real verticalRowHeight: 0
    property int tabIconSize: 0
    property real tabTextSize: Theme.fontSizeSmall
    readonly property bool rotatedTabs: vertical && verticalDisplay === "rotated"
    readonly property bool compactTabs: vertical && !rotatedTabs
    property real maximumWidth: 640
    property real buttonHeight: 30
    // Native artwork can extend beyond the visual pill into the bar's inset.
    property real crossAxisSize: buttonHeight
    readonly property real crossAxisPadding: Math.max(0, (crossAxisSize - buttonHeight) / 2)
    property string barStyle: ""
    property real referenceWidth: 1920
    property real preferredTabWidth: 240
    property var parentScreen: null
    property string barEdge: "top"
    property real barSpacing: 0
    property real barThickness: buttonHeight
    property bool hostReverseScroll: false
    property bool reverseScroll: false
    property var tooltipAnchor: null
    readonly property DTooltip activeTooltip: tooltipLoader.item as DTooltip
    readonly property real gap: Theme.spacingXS
    readonly property var tabLayout: {
        if (compactTabs) {
            return WindowModel.compactTabGeometry(windows.length, gap, controlWidth);
        }
        const minimum = Math.max(96, (buttonHeight + 24) * 1.5, tabIconSize + tabTextSize * 6 + 12);
        return WindowModel.tabGeometry(windows, gap, minimum, referenceWidth, preferredTabWidth);
    }
    property bool animationReady: false
    property real tabOpacity: 1
    property real tabOffset: 0
    property real animatedContentWidth: tabLayout.totalWidth
    onAnimatedContentWidthChanged: Qt.callLater(revealActive)

    Behavior on animatedContentWidth {
        enabled: strip.animationReady && !Theme.snapListModelChanges
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    readonly property real controlWidth: {
        if (compactTabs && verticalRowHeight > 0)
            return verticalRowHeight;
        if (vertical && verticalDisplay === "titles")
            return Math.max(Math.min(buttonHeight, Theme.fontSizeSmall + 24), tabTextSize + 12, tabIconSize + 8);
        return vertical ? Math.max(buttonHeight, tabIconSize + 8) : buttonHeight;
    }
    readonly property var stripLayout: WindowModel.stripGeometry(animatedContentWidth, maximumWidth, controlWidth, gap)
    // During growth, compare against the same animated demand used to size
    // the strip; the final tab width would briefly look like overflow.
    // On removal, use the smaller live content width immediately.
    // The host may still assign less width than our implicit request.
    readonly property bool showArrows: {
        const demand = Math.min(animatedContentWidth, tabLayout.totalWidth);
        return WindowModel.stripGeometry(demand, vertical ? height : width, controlWidth, gap).showArrows;
    }
    readonly property int activeIndex: windows.findIndex(window => window.active)
    readonly property var activeWindowId: activeIndex >= 0 ? windows[activeIndex].id : null
    // Manual browsing lasts until focus changes, even as DMS replaces snapshots.
    property bool followActive: true

    ListModel {
        id: tabs
    }

    function syncTabs() {
        const data = windows.map((window, index) => ({
            windowId: window.id,
            appId: window.appId,
            title: window.title,
            active: !!window.active,
            urgent: !!window.urgent,
            tabWidth: tabLayout.widths[index]
        }));
        if (ModelUtils.syncRows(tabs, data, "windowId"))
            hideTooltip(null);
    }

    onWindowsChanged: {
        if (dragWindowId !== null && (windows.length !== dragIds.length || windows.some((window, index) => window.id
                                                                                                           !== dragIds[index])))
            cancelTabDrag();
        if (droppedPreview && (!windows.some(window => window.id === droppedPreview.sourceId) || !windows.some(window
                                                                                                               => window.id
                                                                                                                  === droppedPreview.target.targetId)))
            droppedPreview = null;
        Qt.callLater(syncTabs);
    }

    property var dragWindowId: null
    property var dragAnchor: null
    property var dragIds: []
    property real dragPointerX: 0
    property real dragPointerY: 0
    readonly property real dragPointerPosition: vertical ? dragPointerY : dragPointerX
    readonly property real dragCrossPosition: vertical ? dragPointerX : dragPointerY
    readonly property real viewportLength: vertical ? viewport.height : viewport.width
    readonly property real scrollOffset: vertical ? viewport.contentY : viewport.contentX
    property real dragGrabOffset: 0
    property var dragTarget: null
    property var pressedAnchor: null
    property var droppedPreview: null
    readonly property var tabVisualPositions: WindowModel.tabVisualPositions(windows, tabLayout, dragWindowId
                                                                             ?? droppedPreview?.sourceId ?? null,
                                                                             dragTarget ?? droppedPreview?.target
                                                                             ?? null, gap)

    function endPress(anchor) {
        if (pressedAnchor !== anchor)
            return;
        pressedAnchor = null;
        Qt.callLater(revealActive);
    }

    function cancelTabDrag() {
        dragWindowId = null;
        dragAnchor = null;
        dragTarget = null;
        pressedAnchor = null;
    }

    function startTabDrag(anchor, windowId, sceneX, sceneY) {
        if (!available || reorderBusy || !windows.some(window => window.id === windowId))
            return;
        hideTooltip(null);
        viewport.cancelFlick();
        followActive = false;
        const pos = mapFromItem(null, sceneX, sceneY);
        const origin = anchor.parent.mapToItem(strip, 0, 0);
        dragGrabOffset = vertical ? pos.y - origin.y : pos.x - origin.x;
        dragAnchor = anchor;
        dragWindowId = windowId;
        dragIds = windows.map(window => window.id);
        moveTabDrag(anchor, sceneX, sceneY);
    }

    function updateDragTarget() {
        dragTarget = WindowModel.tabDropTarget(windows, tabLayout, dragWindowId, dragPointerPosition - dragGrabOffset
                                               + scrollOffset);
    }

    function moveTabDrag(anchor, sceneX, sceneY) {
        if (anchor !== dragAnchor)
            return;
        const pos = mapFromItem(null, sceneX, sceneY);
        dragPointerX = pos.x;
        dragPointerY = pos.y;
        updateDragTarget();
    }

    function finishTabDrag(anchor, sceneX, sceneY) {
        if (anchor !== dragAnchor)
            return;
        moveTabDrag(anchor, sceneX, sceneY);
        const sourceId = dragWindowId;
        const target = dragTarget;
        const insidePrimary = dragPointerPosition >= 0 && dragPointerPosition <= viewportLength;
        const inside = insidePrimary && dragCrossPosition >= 0 && dragCrossPosition <= buttonHeight;
        // Keep the gap in place while Niri confirms the actual reorder.
        droppedPreview = inside && target ? {
                                                sourceId: sourceId,
                                                target: target
                                            } : null;
        cancelTabDrag();
        if (inside && target)
            windowReorderRequested(sourceId, target.targetId, target.after);
        if (!reorderBusy)
            droppedPreview = null;
    }

    Timer {
        interval: 16
        repeat: true
        running: strip.dragWindowId !== null
        onTriggered: {
            if (strip.dragCrossPosition < 0 || strip.dragCrossPosition > strip.buttonHeight)
                return;
            const step = strip.dragPointerPosition < 28 ? -8 : strip.dragPointerPosition > strip.viewportLength - 28 ? 8 :
                                                                                                                       0;
            if (!step)
                return;
            strip.setScrollOffset(WindowModel.scrollPosition(strip.tabLayout, -1, strip.scrollOffset + step,
                                                             strip.viewportLength, false));
            strip.updateDragTarget();
        }
    }

    onAvailableChanged: {
        if (!available) {
            cancelTabDrag();
            droppedPreview = null;
        }
    }
    onReorderBusyChanged: {
        if (reorderBusy)
            cancelTabDrag();
        else
            droppedPreview = null;
        followActive = !reorderBusy;
        if (!reorderBusy)
            Qt.callLater(revealActive);
    }

    function animateWorkspace() {
        workspaceEnter.stop();
        tabOpacity = 1;
        tabOffset = 0;
        hideTooltip(null);
        if (!animationReady || !available || workspaceId === null || !windows.length || Theme.snapListModelChanges)
            return;
        // The live model changes immediately; never delay focus or queue switches.
        tabOpacity = 0;
        tabOffset = Math.min(8, buttonHeight * 0.2);
        workspaceEnter.start();
    }

    onWorkspaceIdChanged: {
        cancelTabDrag();
        droppedPreview = null;
        if (animationReady)
            Qt.callLater(animateWorkspace);
    }

    ParallelAnimation {
        id: workspaceEnter
        NumberAnimation {
            target: strip
            property: "tabOpacity"
            to: 1
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
        NumberAnimation {
            target: strip
            property: "tabOffset"
            to: 0
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    signal windowActivated(var windowId)
    signal windowCloseRequested(var windowId)
    signal windowReorderRequested(var windowId, var targetId, bool after)
    signal launcherRequested
    signal columnScrollRequested(int direction)
    property var wheelState: ({
                                  axis: "",
                                  source: "",
                                  value: 0
                              })

    onReverseScrollChanged: resetWheelState()
    onHostReverseScrollChanged: resetWheelState()

    function resetWheelState() {
        wheelState = {
            axis: "",
            source: "",
            value: 0
        };
    }

    function handleWheel(wheel) {
        if (!available) {
            wheel.accepted = false;
            return;
        }
        // Consume wheel input so DMS cannot also switch workspaces.
        wheel.accepted = true;
        if (dragWindowId !== null)
            return;
        hideTooltip(null);
        wheelState = WindowModel.wheelNavigation(wheelState, wheel.angleDelta.x, wheel.angleDelta.y, wheel.pixelDelta?.x ?? 0,
                                                 wheel.pixelDelta?.y ?? 0, hostReverseScroll, reverseScroll);
        for (let step = 0; step < wheelState.steps; step++)
            columnScrollRequested(wheelState.direction);
    }

    MouseArea {
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        onWheel: wheel => strip.handleWheel(wheel)
    }

    implicitHeight: vertical ? stripLayout.width : buttonHeight
    implicitWidth: vertical ? buttonHeight : stripLayout.width
    width: implicitWidth
    height: implicitHeight
    clip: crossAxisPadding === 0

    function showTooltip(anchor) {
        if (!parentScreen || viewport.moving || !anchor.hovered || dragWindowId !== null || workspaceEnter.running ||
                !anchor.enabled || !anchor.tooltip.length)
            return;
        tooltipAnchor = anchor;
        tooltipLoader.active = true;
        if (!activeTooltip)
            return;
        // Use the same screen-local anchor and panel tooltip as DMS RunningApps.
        activeTooltip.text = anchor.tooltip;
        if (vertical) {
            const center = anchor.mapToItem(null, anchor.width / 2, anchor.height / 2);
            const left = barEdge !== "right";
            const inset = barThickness + barSpacing + gap;
            const tooltipX = left ? inset : parentScreen.width - inset;
            activeTooltip.show(anchor.tooltip, tooltipX, center.y, parentScreen, left, !left);
            return;
        }
        const pos = anchor.mapToItem(null, anchor.width / 2, anchor.height);
        const inset = barThickness + barSpacing + gap;
        const tooltipY = barEdge === "bottom" ? parentScreen.height - inset - activeTooltip.implicitHeight : inset;
        activeTooltip.show(anchor.tooltip, pos.x, tooltipY, parentScreen, false, false);
    }

    function hideTooltip(anchor) {
        if (anchor && anchor !== tooltipAnchor)
            return;
        tooltipAnchor = null;
        if (activeTooltip)
            activeTooltip.hide();
        tooltipLoader.active = false;
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }

    onVisibleChanged: {
        if (!visible) {
            hideTooltip(null);
            cancelTabDrag();
            droppedPreview = null;
        }
    }
    onParentScreenChanged: {
        cancelTabDrag();
        droppedPreview = null;
        hideTooltip(null);
        resetWheelState();
    }

    function setScrollOffset(offset) {
        if (vertical)
            viewport.contentY = offset;
        else
            viewport.contentX = offset;
    }

    function resetOrientation() {
        hideTooltip(null);
        cancelTabDrag();
        droppedPreview = null;
        followActive = true;
        resetWheelState();
        viewport.contentX = 0;
        viewport.contentY = 0;
        Qt.callLater(revealActive);
    }
    onVerticalChanged: resetOrientation()
    onVerticalDisplayChanged: resetOrientation()

    function scrollBy(amount) {
        hideTooltip(null);
        followActive = false;
        viewport.cancelFlick();
        setScrollOffset(WindowModel.scrollPosition(tabLayout, activeIndex, scrollOffset + amount, viewportLength,
                                                   false));
    }

    function revealActive() {
        if (viewport.moving || dragWindowId !== null || pressedAnchor !== null)
            return;
        // A new rightmost tab can be temporarily clipped while the strip
        // grows. Revealing it now would scroll existing tabs and then undo
        // that scroll on every frame. Clamp now, reveal when growth settles.
        setScrollOffset(WindowModel.scrollPosition(tabLayout, activeIndex, scrollOffset, viewportLength, followActive
                                                   && animatedContentWidth >= tabLayout.totalWidth));
    }

    onActiveWindowIdChanged: {
        // Internal focus staging for swaps must not yank overflow browsing.
        followActive = !reorderBusy;
        viewport.cancelFlick();
        Qt.callLater(revealActive);
    }
    onTabLayoutChanged: {
        Qt.callLater(syncTabs);
        Qt.callLater(revealActive);
    }
    Component.onCompleted: {
        syncTabs();
        animationReady = true;
        Qt.callLater(revealActive);
    }

    Flickable {
        id: viewport
        opacity: strip.tabOpacity
        visible: strip.windows.length > 0
        x: strip.vertical ? -strip.crossAxisPadding : 0
        y: strip.vertical ? 0 : -strip.crossAxisPadding
        readonly property real controlGap: visible ? strip.gap : 0
        width: strip.vertical ? strip.crossAxisSize : Math.max(0, strip.width - controls.width - controlGap)
        height: strip.vertical ? Math.max(0, strip.height - controls.height - controlGap) : strip.crossAxisSize
        contentWidth: strip.vertical ? width : strip.tabLayout.totalWidth
        contentHeight: strip.vertical ? strip.tabLayout.totalWidth : height
        flickableDirection: strip.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        interactive: strip.dragWindowId === null
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        onWidthChanged: Qt.callLater(strip.revealActive)
        onHeightChanged: Qt.callLater(strip.revealActive)
        onMovementStarted: strip.hideTooltip(null)
        onDraggingChanged: {
            if (dragging) {
                strip.hideTooltip(null);
                strip.followActive = false;
            }
        }
        onMovementEnded: Qt.callLater(strip.revealActive)

        Grid {
            x: strip.vertical ? strip.crossAxisPadding : 0
            y: strip.tabOffset + (strip.vertical ? 0 : strip.crossAxisPadding)
            columns: strip.vertical ? 1 : Math.max(1, tabs.count)
            spacing: strip.gap

            Repeater {
                model: tabs

                Item {
                    id: tab
                    required property var windowId
                    required property string appId
                    required property string title
                    required property bool active
                    required property bool urgent
                    required property real tabWidth
                    required property int index
                    width: strip.vertical ? strip.buttonHeight : tabWidth
                    height: strip.vertical ? tabWidth : strip.buttonHeight
                    z: strip.dragWindowId === windowId || strip.droppedPreview?.sourceId === windowId ? 1 : 0
                    // Animate one absolute position per tab. Animating layout and
                    // a preview offset separately caused jumps on layout acknowledgment.
                    property real visualPosition: {
                        if (strip.dragWindowId === windowId)
                            return strip.dragPointerPosition - strip.dragGrabOffset + strip.scrollOffset;
                        return strip.tabVisualPositions[windowId] ?? (strip.vertical ? y : x);
                    }
                    transform: Translate {
                        x: strip.vertical ? 0 : tab.visualPosition - tab.x
                        y: strip.vertical ? tab.visualPosition - tab.y : 0
                    }
                    property real entranceOpacity: 0
                    opacity: entranceOpacity
                    Component.onCompleted: entranceOpacity = 1
                    Behavior on visualPosition {
                        enabled: strip.animationReady && !Theme.snapListModelChanges && strip.dragWindowId
                                 !== tab.windowId
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    Behavior on entranceOpacity {
                        enabled: strip.animationReady && !Theme.snapListModelChanges
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    NavigationButton {
                        id: tabButton
                        anchors.centerIn: parent
                        width: strip.rotatedTabs ? tab.height : tab.width
                        height: strip.rotatedTabs ? tab.width : tab.height
                        rotation: strip.rotatedTabs ? (strip.barEdge === "right" ? -90 : 90) : 0
                        showText: strip.showTitles
                        textOpacity: strip.titleOpacity
                        iconSize: strip.tabIconSize
                        barStyle: strip.barStyle
                        textSize: strip.tabTextSize
                        appId: tab.appId
                        faviconSource: strip.faviconSources[tab.windowId] ?? ""
                        showAppIcon: true
                        acceptMiddleClick: true
                        activateOnPress: true
                        opaqueBackground: strip.pressedAnchor === tabButton || strip.dragWindowId === tab.windowId
                                          || strip.droppedPreview?.sourceId === tab.windowId
                        dragEnabled: strip.available && !strip.reorderBusy
                        text: tab.title
                        selected: tab.active
                        urgent: tab.urgent
                        tooltip: applicationName ? applicationName + " • " + tab.title : tab.title
                        onTooltipRequested: anchor => strip.showTooltip(anchor)
                        onTooltipDismissed: anchor => strip.hideTooltip(anchor)
                        onClicked: strip.windowActivated(tab.windowId)
                        onPressStarted: anchor => {
                            strip.pressedAnchor = anchor;
                        }
                        onPressEnded: anchor => strip.endPress(anchor)
                        onMiddleClicked: strip.windowCloseRequested(tab.windowId)
                        onTabDragStarted: (anchor, x, y) => strip.startTabDrag(anchor, tab.windowId, x, y)
                        onTabDragMoved: (anchor, x, y) => strip.moveTabDrag(anchor, x, y)
                        onTabDragFinished: (anchor, x, y) => strip.finishTabDrag(anchor, x, y)
                        onTabDragCanceled: anchor => {
                            if (strip.dragAnchor === anchor)
                                strip.cancelTabDrag();
                        }
                    }
                }
            }
        }
    }

    component StripControl: NavigationButton {
        textSize: strip.tabTextSize
        barStyle: strip.barStyle
        width: strip.vertical ? strip.buttonHeight : strip.controlWidth
        height: strip.vertical ? strip.controlWidth : strip.buttonHeight
        onTooltipRequested: anchor => strip.showTooltip(anchor)
        onTooltipDismissed: anchor => strip.hideTooltip(anchor)
        onPressStarted: anchor => strip.pressedAnchor = anchor
        onPressEnded: anchor => strip.endPress(anchor)
    }

    Grid {
        id: controls
        // Empty horizontal columns retain spacing even with hidden arrows.
        // Match the model's one-control budget when only the launcher shows.
        columns: strip.vertical || !strip.showArrows ? 1 : 3
        x: strip.vertical ? 0 : strip.width - width
        y: strip.vertical ? strip.height - height : 0
        spacing: strip.gap

        StripControl {
            visible: strip.showArrows
            text: strip.vertical ? "↑" : "‹"
            tooltip: "Earlier windows"
            enabled: strip.scrollOffset > 0
            onClicked: strip.scrollBy(-strip.viewportLength * 0.8)
        }

        StripControl {
            visible: strip.showArrows
            text: strip.vertical ? "↓" : "›"
            tooltip: "Later windows"
            enabled: strip.scrollOffset < strip.tabLayout.totalWidth - strip.viewportLength
            onClicked: strip.scrollBy(strip.viewportLength * 0.8)
        }

        StripControl {
            text: "+"
            tooltip: "Open app launcher"
            enabled: strip.available
            onClicked: strip.launcherRequested()
        }
    }
}
