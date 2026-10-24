pragma ComponentBehavior: Bound

import QtQuick
import qs.Services

NavigationHost {
    id: navigation

    readonly property real configuredMaximumWidth: Number(pluginData.maximumWidth)
    readonly property real stripLength: {
        if (pluginData.allowFullWidth !== false)
            return primarySizeLimit;
        const valid = Number.isFinite(configuredMaximumWidth) && configuredMaximumWidth > 0;
        const limit = valid ? Math.max(240, Math.min(7680, configuredMaximumWidth)) : 640;
        return Math.min(primarySizeLimit, limit);
    }

    NiriState {
        id: niri
        outputName: navigation.parentScreen?.name ?? ""
        workspaceIconsEnabled: false
    }

    navigationContent: Component {
        WindowStrip {
            vertical: navigation.isVertical
            verticalDisplay: navigation.pluginData.verticalDisplay ?? "icons"
            windows: niri.currentWindows
            faviconSources: niri.faviconSources
            workspaceId: niri.activeWorkspace?.id ?? null
            available: niri.available
            reorderBusy: niri.reorderBusy
            maximumWidth: navigation.stripLength
            buttonHeight: navigation.isVertical ? navigation.widgetThickness : navigation.barThickness
            referenceWidth: navigation.parentScreen?.width ?? 1920
            preferredTabWidth: Number(navigation.pluginData.tabWidth) || 240
            parentScreen: navigation.parentScreen
            barEdge: navigation.axis?.edge ?? "top"
            barSpacing: navigation.barSpacing
            barThickness: navigation.barThickness
            reverseScroll: navigation.pluginData.reverseScroll === true
            onColumnScrollRequested: direction => niri.scrollColumn(direction)
            onWindowActivated: windowId => niri.focusWindow(windowId)
            onWindowCloseRequested: windowId => niri.closeWindow(windowId)
            onWindowReorderRequested: (windowId, targetId, after) => niri.reorderWindow(windowId, targetId, after)
            onLauncherRequested: PopoutService.openDankLauncherV2()
        }
    }
}
