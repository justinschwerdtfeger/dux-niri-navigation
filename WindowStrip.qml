pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import "WindowModel.js" as WindowModel

Item {
    id: strip

    property var windows: []
    property bool available: false
    property real maximumWidth: 640
    property real buttonHeight: 30
    property real referenceWidth: 1920
    readonly property real gap: Theme.spacingXS
    readonly property var tabLayout: WindowModel.tabGeometry(windows, gap,
        Math.max(96, (buttonHeight + 24) * 1.5), referenceWidth)
    readonly property real controlWidth: buttonHeight
    readonly property var stripLayout: WindowModel.stripGeometry(
        tabLayout.totalWidth, maximumWidth, controlWidth, gap)
    // The host may assign less width than our implicit request.
    readonly property bool showArrows: WindowModel.stripGeometry(
        tabLayout.totalWidth, width, controlWidth, gap).showArrows
    readonly property int activeIndex: windows.findIndex(window => window.active)
    readonly property var activeWindowId: activeIndex >= 0 ? windows[activeIndex].id : null
    // Manual browsing lasts until focus changes, even as DMS replaces snapshots.
    property bool followActive: true

    signal windowActivated(var windowId)
    signal launcherRequested()

    implicitHeight: buttonHeight
    implicitWidth: stripLayout.width
    width: implicitWidth
    height: implicitHeight
    clip: true

    function scrollBy(amount) {
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
    onTabLayoutChanged: Qt.callLater(revealActive)
    Component.onCompleted: Qt.callLater(revealActive)

    Flickable {
        id: viewport
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
        onDraggingChanged: {
            if (dragging)
                strip.followActive = false;
        }
        onMovementEnded: Qt.callLater(strip.revealActive)

        Row {
            spacing: strip.gap

            Repeater {
                model: strip.windows

                NavigationButton {
                    required property var modelData
                    required property int index
                    width: strip.tabLayout.widths[index]
                    height: strip.buttonHeight
                    appId: modelData.appId
                    showAppIcon: true
                    text: modelData.title
                    selected: modelData.active
                    urgent: modelData.urgent
                    tooltip: modelData.title
                    onClicked: strip.windowActivated(modelData.id)
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
            text: "‹"
            tooltip: "Earlier windows"
            enabled: viewport.contentX > 0
            onClicked: strip.scrollBy(-viewport.width * 0.8)
        }

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
            visible: strip.showArrows
            text: "›"
            tooltip: "Later windows"
            enabled: viewport.contentX < viewport.contentWidth - viewport.width
            onClicked: strip.scrollBy(viewport.width * 0.8)
        }

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
            text: "+"
            tooltip: "Open app launcher"
            enabled: strip.available
            onClicked: strip.launcherRequested()
        }
    }
}
