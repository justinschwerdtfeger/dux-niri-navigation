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
    property real maximumWidth: 640
    property real buttonHeight: 30
    property real referenceWidth: 1920
    property real preferredTabWidth: 240
    property var parentScreen: null
    property string barEdge: "top"
    property real barSpacing: 0
    property bool reverseScroll: false
    property var tooltipAnchor: null
    readonly property DankTooltip activeTooltip: tooltipLoader.item as DankTooltip
    readonly property real gap: Theme.spacingXS
    readonly property var tabLayout: {
        const minimum = Math.max(96, (buttonHeight + 24) * 1.5);
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

    readonly property real controlWidth: buttonHeight
    readonly property var stripLayout: WindowModel.stripGeometry(animatedContentWidth, maximumWidth, controlWidth, gap)
    // During growth, compare against the same animated demand used to size
    // the strip; the final tab width would briefly look like overflow.
    // On removal, use the smaller live content width immediately.
    // The host may still assign less width than our implicit request.
    readonly property bool showArrows: {
        const demand = Math.min(animatedContentWidth, tabLayout.totalWidth);
        return WindowModel.stripGeometry(demand, width, controlWidth, gap).showArrows;
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
    property real dragGrabOffset: 0
    property var dragTarget: null
    property var pressedTabAnchor: null
    property var droppedPreview: null
    readonly property var tabVisualPositions: WindowModel.tabVisualPositions(windows, tabLayout, dragWindowId
                                                                             ?? droppedPreview?.sourceId ?? null,
                                                                             dragTarget ?? droppedPreview?.target
                                                                             ?? null, gap)

    function endTabPress(anchor) {
        if (pressedTabAnchor !== anchor)
            return;
        pressedTabAnchor = null;
        Qt.callLater(revealActive);
    }

    function cancelTabDrag() {
        dragWindowId = null;
        dragAnchor = null;
        dragTarget = null;
        pressedTabAnchor = null;
    }

    function startTabDrag(anchor, windowId, sceneX, sceneY) {
        if (!available || reorderBusy || !windows.some(window => window.id === windowId))
            return;
        hideTooltip(null);
        viewport.cancelFlick();
        followActive = false;
        const pos = mapFromItem(null, sceneX, sceneY);
        dragGrabOffset = pos.x - anchor.mapToItem(strip, 0, 0).x;
        dragAnchor = anchor;
        dragWindowId = windowId;
        dragIds = windows.map(window => window.id);
        moveTabDrag(anchor, sceneX, sceneY);
    }

    function updateDragTarget() {
        dragTarget = WindowModel.tabDropTarget(windows, tabLayout, dragWindowId, dragPointerX - dragGrabOffset
                                               + viewport.contentX);
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
        const insideX = dragPointerX >= 0 && dragPointerX <= viewport.width;
        const inside = insideX && dragPointerY >= 0 && dragPointerY <= buttonHeight;
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
            if (strip.dragPointerY < 0 || strip.dragPointerY > strip.buttonHeight)
                return;
            const step = strip.dragPointerX < 28 ? -8 : strip.dragPointerX > viewport.width - 28 ? 8 : 0;
            if (!step)
                return;
            viewport.contentX = WindowModel.scrollPosition(strip.tabLayout, -1, viewport.contentX + step, viewport.width,
                                                           false);
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

    onReverseScrollChanged: {
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
                                                 wheel.pixelDelta?.y ?? 0, SettingsData.reverseScrolling,
                                                 reverseScroll);
        for (let step = 0; step < wheelState.steps; step++)
            columnScrollRequested(wheelState.direction);
    }

    MouseArea {
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        onWheel: wheel => strip.handleWheel(wheel)
    }

    implicitHeight: buttonHeight
    implicitWidth: stripLayout.width
    width: implicitWidth
    height: implicitHeight
    clip: true

    function showTooltip(anchor) {
        if (!parentScreen || viewport.moving || !anchor.hovered || dragWindowId !== null || workspaceEnter.running ||
                !anchor.enabled || !anchor.tooltip.length)
            return;
        tooltipAnchor = anchor;
        tooltipLoader.active = true;
        if (!activeTooltip)
            return;
        // Use the same screen-local anchor and panel tooltip as DMS RunningApps.
        const pos = anchor.mapToItem(null, anchor.width / 2, anchor.height);
        activeTooltip.text = anchor.tooltip;
        const tooltipY = barEdge === "bottom" ? parentScreen.height - buttonHeight - barSpacing - gap
                                                - activeTooltip.implicitHeight : buttonHeight + barSpacing + gap;
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
        sourceComponent: DankTooltip {}
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
        wheelState = {
            axis: "",
            source: "",
            value: 0
        };
    }

    function scrollBy(amount) {
        hideTooltip(null);
        followActive = false;
        viewport.cancelFlick();
        viewport.contentX = WindowModel.scrollPosition(tabLayout, activeIndex, viewport.contentX + amount, viewport.width,
                                                       false);
    }

    function revealActive() {
        if (viewport.moving || dragWindowId !== null || pressedTabAnchor !== null)
            return;
        // A new rightmost tab can be temporarily clipped while the strip
        // grows. Revealing it now would scroll existing tabs and then undo
        // that scroll on every frame. Clamp now, reveal when growth settles.
        viewport.contentX = WindowModel.scrollPosition(tabLayout, activeIndex, viewport.contentX, viewport.width,
                                                       followActive && animatedContentWidth >= tabLayout.totalWidth);
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
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: controls.left
        anchors.rightMargin: visible ? strip.gap : 0
        height: strip.buttonHeight
        contentWidth: strip.tabLayout.totalWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        interactive: strip.dragWindowId === null
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        onWidthChanged: Qt.callLater(strip.revealActive)
        onMovementStarted: strip.hideTooltip(null)
        onDraggingChanged: {
            if (dragging) {
                strip.hideTooltip(null);
                strip.followActive = false;
            }
        }
        onMovementEnded: Qt.callLater(strip.revealActive)

        Row {
            spacing: strip.gap
            transform: Translate {
                y: strip.tabOffset
            }

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
                    width: tabWidth
                    height: strip.buttonHeight
                    z: strip.dragWindowId === windowId || strip.droppedPreview?.sourceId === windowId ? 1 : 0
                    // Animate one absolute position per tab. Animating Row.x and
                    // a preview offset separately caused jumps on layout acknowledgment.
                    property real visualX: strip.dragWindowId === windowId ? strip.dragPointerX - strip.dragGrabOffset
                                                                             + viewport.contentX : (
                                                                                 strip.tabVisualPositions[windowId]
                                                                                 ?? x)
                    property real entranceOpacity: 0
                    opacity: entranceOpacity
                    Component.onCompleted: entranceOpacity = 1
                    Behavior on visualX {
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
                        anchors.fill: parent
                        appId: tab.appId
                        faviconSource: strip.faviconSources[tab.windowId] ?? ""
                        showAppIcon: true
                        acceptMiddleClick: true
                        activateOnPress: true
                        opaqueBackground: strip.pressedTabAnchor === tabButton || strip.dragWindowId === tab.windowId
                                          || strip.droppedPreview?.sourceId === tab.windowId
                        dragEnabled: strip.available && !strip.reorderBusy
                        transform: Translate {
                            x: tab.visualX - tab.x
                        }
                        text: tab.title
                        selected: tab.active
                        urgent: tab.urgent
                        tooltip: applicationName ? applicationName + " • " + tab.title : tab.title
                        onTooltipRequested: anchor => strip.showTooltip(anchor)
                        onTooltipDismissed: anchor => strip.hideTooltip(anchor)
                        onClicked: strip.windowActivated(tab.windowId)
                        onPressStarted: anchor => {
                            strip.pressedTabAnchor = anchor;
                        }
                        onPressEnded: anchor => strip.endTabPress(anchor)
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

    Row {
        id: controls
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: strip.gap

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
            visible: strip.showArrows
            onTooltipRequested: anchor => strip.showTooltip(anchor)
            onTooltipDismissed: anchor => strip.hideTooltip(anchor)
            text: "‹"
            tooltip: "Earlier windows"
            enabled: viewport.contentX > 0
            onClicked: strip.scrollBy(-viewport.width * 0.8)
        }

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
            visible: strip.showArrows
            onTooltipRequested: anchor => strip.showTooltip(anchor)
            onTooltipDismissed: anchor => strip.hideTooltip(anchor)
            text: "›"
            tooltip: "Later windows"
            enabled: viewport.contentX < viewport.contentWidth - viewport.width
            onClicked: strip.scrollBy(viewport.width * 0.8)
        }

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
            onTooltipRequested: anchor => strip.showTooltip(anchor)
            onTooltipDismissed: anchor => strip.hideTooltip(anchor)
            text: "+"
            tooltip: "Open app launcher"
            enabled: strip.available
            onClicked: strip.launcherRequested()
        }
    }
}
