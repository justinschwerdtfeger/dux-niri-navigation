pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import "WindowModel.js" as WindowModel

Item {
    id: strip

    property var windows: []
    property var workspaceId: null
    property bool available: false
    property real maximumWidth: 640
    property real buttonHeight: 30
    property real referenceWidth: 1920
    property real preferredTabWidth: 240
    property var parentScreen: null
    property string barEdge: "top"
    property real barSpacing: 0
    property bool reverseScroll: true
    property var tooltipAnchor: null
    readonly property real gap: Theme.spacingXS
    readonly property var tabLayout: WindowModel.tabGeometry(windows, gap,
        Math.max(96, (buttonHeight + 24) * 1.5), referenceWidth, preferredTabWidth)
    property bool animationReady: false
    property real tabOpacity: 1
    property real tabOffset: 0
    property real animatedContentWidth: tabLayout.totalWidth

    Behavior on animatedContentWidth {
        enabled: strip.animationReady && !Theme.snapListModelChanges
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    readonly property real controlWidth: buttonHeight
    readonly property var stripLayout: WindowModel.stripGeometry(
        animatedContentWidth, maximumWidth, controlWidth, gap)
    // The host may assign less width than our implicit request.
    readonly property bool showArrows: WindowModel.stripGeometry(
        tabLayout.totalWidth, width, controlWidth, gap).showArrows
    readonly property int activeIndex: windows.findIndex(window => window.active)
    readonly property var activeWindowId: activeIndex >= 0 ? windows[activeIndex].id : null
    // Manual browsing lasts until focus changes, even as DMS replaces snapshots.
    property bool followActive: true

    ListModel { id: tabs }

    Transition {
        id: tabMove
        NumberAnimation {
            properties: "x,y"
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
        // A reorder can interrupt an entrance; finish its opacity as well.
        NumberAnimation {
            property: "opacity"
            to: 1
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Transition {
        id: tabAdd
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    function syncTabs() {
        const previousIds = [];
        for (let i = 0; i < tabs.count; i++)
            previousIds.push(tabs.get(i).windowId);
        const data = windows.map((window, index) => ({
            windowId: window.id, appId: window.appId, title: window.title,
            active: !!window.active, urgent: !!window.urgent,
            tabWidth: tabLayout.widths[index]
        }));
        const changes = WindowModel.tabModelChanges(previousIds, windows.map(window => window.id));
        if (changes.length)
            hideTooltip(null);
        for (const change of changes) {
            if (change.type === "remove")
                tabs.remove(change.index);
            else if (change.type === "insert")
                tabs.insert(change.index, data[change.index]);
            else
                tabs.move(change.from, change.index, 1);
        }
        data.forEach((window, index) => tabs.set(index, window));
    }

    onWindowsChanged: Qt.callLater(syncTabs)

    function animateWorkspace() {
        workspaceEnter.stop();
        tabOpacity = 1;
        tabOffset = 0;
        hideTooltip(null);
        if (!animationReady || !available || workspaceId === null
                || !windows.length || Theme.snapListModelChanges)
            return;
        // The live model changes immediately; never delay focus or queue switches.
        tabOpacity = 0;
        tabOffset = Math.min(8, buttonHeight * 0.2);
        workspaceEnter.start();
    }

    onWorkspaceIdChanged: {
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
    signal launcherRequested()
    signal columnScrollRequested(int direction)
    property var wheelState: ({ axis: "", source: "", value: 0 })

    onReverseScrollChanged: {
        wheelState = { axis: "", source: "", value: 0 };
    }

    function handleWheel(wheel) {
        if (!available) {
            wheel.accepted = false;
            return;
        }
        // Consume wheel input so DMS cannot also switch workspaces.
        wheel.accepted = true;
        hideTooltip(null);
        wheelState = WindowModel.wheelNavigation(wheelState,
            wheel.angleDelta.x, wheel.angleDelta.y,
            wheel.pixelDelta?.x ?? 0, wheel.pixelDelta?.y ?? 0,
            SettingsData.reverseScrolling, reverseScroll);
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
        if (!parentScreen || viewport.moving || !anchor.hovered
                || workspaceEnter.running || !anchor.enabled || !anchor.tooltip.length)
            return;
        tooltipAnchor = anchor;
        tooltipLoader.active = true;
        if (!tooltipLoader.item)
            return;
        // Use the same screen-local anchor and panel tooltip as DMS RunningApps.
        const pos = anchor.mapToItem(null, anchor.width / 2, anchor.height);
        tooltipLoader.item.text = anchor.tooltip;
        const tooltipY = barEdge === "bottom"
            ? parentScreen.height - buttonHeight - barSpacing - gap - tooltipLoader.item.implicitHeight
            : buttonHeight + barSpacing + gap;
        tooltipLoader.item.show(anchor.tooltip, pos.x, tooltipY, parentScreen, false, false);
    }

    function hideTooltip(anchor) {
        if (anchor && anchor !== tooltipAnchor)
            return;
        tooltipAnchor = null;
        if (tooltipLoader.item)
            tooltipLoader.item.hide();
        tooltipLoader.active = false;
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    onVisibleChanged: { if (!visible) hideTooltip(null); }
    onParentScreenChanged: {
        hideTooltip(null);
        wheelState = { axis: "", source: "", value: 0 };
    }

    function scrollBy(amount) {
        hideTooltip(null);
        followActive = false;
        viewport.cancelFlick();
        viewport.contentX = WindowModel.scrollPosition(tabLayout, activeIndex,
            viewport.contentX + amount, viewport.width, false);
    }

    function revealActive() {
        if (viewport.moving)
            return;
        viewport.contentX = WindowModel.scrollPosition(tabLayout, activeIndex,
            viewport.contentX, viewport.width, followActive);
    }

    onActiveWindowIdChanged: {
        followActive = true;
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
        console.info("Justin Navigation: workspace transitions and tab movement loaded; wheel input has no cooldown, 120 angle units per step");
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
            transform: Translate { y: strip.tabOffset }

            move: strip.animationReady && !Theme.snapListModelChanges ? tabMove : null
            add: strip.animationReady && !Theme.snapListModelChanges ? tabAdd : null

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
                    width: tabWidth
                    height: strip.buttonHeight

                    NavigationButton {
                        anchors.fill: parent
                        appId: tab.appId
                        showAppIcon: true
                        acceptMiddleClick: true
                        text: tab.title
                        selected: tab.active
                        urgent: tab.urgent
                        tooltip: applicationName
                            ? applicationName + " • " + tab.title : tab.title
                        onTooltipRequested: anchor => strip.showTooltip(anchor)
                        onTooltipDismissed: anchor => strip.hideTooltip(anchor)
                        onClicked: strip.windowActivated(tab.windowId)
                        onMiddleClicked: strip.windowCloseRequested(tab.windowId)
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
