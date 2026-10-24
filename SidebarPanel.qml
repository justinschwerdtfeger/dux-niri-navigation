pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import "SidebarModel.js" as SidebarModel

// Quickshell registers the platform's PanelWindow factory at runtime;
// its public metadata describes the uncreatable base interface instead.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: panel

    property var pluginData: ({})
    readonly property var configuration: SidebarModel.configuration(pluginData, screen?.width ?? 1920)

    function toggleExpansion() {
        view.toggleExpansion();
    }

    WlrLayershell.namespace: "dms:justin-window-sidebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.bottom: true
    anchors.left: configuration.side === "left"
    anchors.right: configuration.side === "right"
    // Keep Wayland buffer/configure sizes stable throughout the animation.
    implicitWidth: view.panelGeometry.surfaceWidth
    exclusiveZone: Math.ceil(view.panelGeometry.reservedWidth)
    color: "transparent"
    mask: Region {
        item: view
    }

    NiriState {
        id: niri
        outputName: panel.screen?.name ?? ""
        workspaceIconsEnabled: false
    }

    SidebarView {
        id: view
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: implicitWidth
        x: panel.configuration.side === "right" ? parent.width - width : 0
        configuration: panel.configuration
        windows: niri.currentWindows
        faviconSources: niri.faviconSources
        workspaceId: niri.activeWorkspace?.id ?? null
        available: niri.available
        reorderBusy: niri.reorderBusy
        parentScreen: panel.screen
        reverseScroll: panel.pluginData.reverseScroll === true
        onColumnScrollRequested: direction => niri.scrollColumn(direction)
        onWindowActivated: windowId => niri.focusWindow(windowId)
        onWindowCloseRequested: windowId => niri.closeWindow(windowId)
        onWindowReorderRequested: (windowId, targetId, after) => niri.reorderWindow(windowId, targetId, after)
        onLauncherRequested: PopoutService.openDankLauncherV2()
    }
}
