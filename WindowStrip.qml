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
        Math.max(64, buttonHeight + 24), referenceWidth)
    readonly property real controlWidth: buttonHeight
    readonly property int activeIndex: windows.findIndex(window => window.active)
    readonly property var activeWindowId: activeIndex >= 0 ? windows[activeIndex].id : null
    // Manual browsing lasts until focus changes, even as DMS replaces snapshots.
    property bool followActive: true

    signal windowActivated(var windowId)
    signal launcherRequested()

    implicitHeight: buttonHeight
    implicitWidth: Math.min(maximumWidth,
        Math.max(160, tabLayout.totalWidth)
        + controlWidth * 3 + gap * 3)
    width: implicitWidth
    height: implicitHeight

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

    Row {
        anchors.fill: parent
        spacing: strip.gap

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
            text: "‹"
            tooltip: "Earlier windows"
            enabled: viewport.contentX > 0
            onClicked: strip.scrollBy(-viewport.width * 0.8)
        }

        Flickable {
            id: viewport
            width: Math.max(1, strip.width - strip.controlWidth * 3 - strip.gap * 3)
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
                id: titles
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
                        tooltip: modelData.title + (modelData.floating ? " (floating)" : "")
                        onClicked: strip.windowActivated(modelData.id)
                    }
                }
            }

            StyledText {
                // Flickable reparents children into its content item, whose
                // width is zero when empty. Center in the visible viewport.
                x: viewport.contentX + (viewport.width - width) / 2
                y: (viewport.height - height) / 2
                visible: strip.windows.length === 0
                text: strip.available ? "No windows" : "Niri required"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        NavigationButton {
            width: strip.controlWidth
            height: strip.buttonHeight
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
