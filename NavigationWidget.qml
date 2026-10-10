pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import "WorkspaceModel.js" as WorkspaceModel

PluginComponent {
    id: navigation

    // DMS 1.6.2 owns the BasePill, but exposes no full-height plugin option.
    // Match by its content component, not child order or the loader hierarchy.
    readonly property var horizontalPillHost: findPill(horizontalBarPill)

    function findPill(content) {
        return children.find(child => "content" in child && child.content === content) ?? null;
    }

    Binding {
        target: navigation.horizontalPillHost
        property: "widgetThickness"
        value: navigation.barThickness
        when: navigation.horizontalPillHost !== null && !navigation.isVertical
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Like DMS RunningApps, only the individual buttons are interactive.
    readonly property var verticalPillHost: findPill(verticalBarPill)
    readonly property var activePillHost: isVertical ? verticalPillHost : horizontalPillHost

    Binding {
        target: navigation.activePillHost
        property: "enableBackgroundHover"
        value: false
        when: navigation.activePillHost !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: navigation.activePillHost
        property: "enableCursor"
        value: false
        when: navigation.activePillHost !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    readonly property real pillPadding: {
        if (barConfig?.removeWidgetPadding ?? false)
            return 0;
        const thickness = isVertical ? widgetThickness : barThickness;
        return (barConfig?.widgetPadding ?? 12) * thickness / 30;
    }
    BarGeometry {
        id: barGeometry
        widget: navigation
        vertical: navigation.isVertical
        section: navigation.section
        pillPadding: navigation.pillPadding
        pillHost: navigation.activePillHost
    }
    // Fall back only while the host is being constructed or is unsupported.
    readonly property real hostWidthLimit: {
        const available = barGeometry.host !== null ? barGeometry.availableWidth : (parentScreen?.width ?? 1920)
                                                      - pillPadding * 2;
        return Math.max(barThickness, available);
    }
    readonly property real configuredMaximumWidth: Number(pluginData.maximumWidth)
    readonly property real stripWidth: {
        if (pluginData.allowFullWidth !== false)
            return hostWidthLimit;
        const valid = Number.isFinite(configuredMaximumWidth) && configuredMaximumWidth > 0;
        const limit = valid ? Math.max(240, Math.min(7680, configuredMaximumWidth)) : 640;
        return Math.min(hostWidthLimit, limit);
    }

    NiriState {
        id: niri
        outputName: navigation.parentScreen?.name ?? ""
        faviconsEnabled: !navigation.isVertical
    }

    horizontalBarPill: Component {
        WindowStrip {
            windows: niri.currentWindows
            faviconSources: niri.faviconSources
            workspaceId: niri.activeWorkspace?.id ?? null
            available: niri.available
            reorderBusy: niri.reorderBusy
            maximumWidth: navigation.stripWidth
            // Match the full-height horizontal BasePill.
            buttonHeight: navigation.barThickness
            referenceWidth: navigation.parentScreen?.width ?? 1920
            preferredTabWidth: Number(navigation.pluginData.tabWidth) || 240
            parentScreen: navigation.parentScreen
            barEdge: navigation.axis?.edge ?? "top"
            barSpacing: navigation.barSpacing
            reverseScroll: navigation.pluginData.reverseScroll === true
            onColumnScrollRequested: direction => niri.scrollColumn(direction)
            onWindowActivated: windowId => niri.focusWindow(windowId)
            onWindowCloseRequested: windowId => niri.closeWindow(windowId)
            onWindowReorderRequested: (windowId, targetId, after) => niri.reorderWindow(windowId, targetId, after)
            // DMS chooses the launcher's output; this API does not accept a screen.
            onLauncherRequested: PopoutService.openDankLauncherV2()
        }
    }

    property var editingWorkspaceId: null
    readonly property var editingWorkspace: niri.outputWorkspaces.find(ws => ws.id === editingWorkspaceId) ?? null
    readonly property var pinnedWorkspaceIcons: WorkspaceModel.pinnedIcons(pluginData.pinnedWorkspaceIcons)
    onEditingWorkspaceChanged: {
        if (!editingWorkspace)
            iconPopout.close();
    }

    function openIconMenu(workspaceId, anchor) {
        if (!WorkspaceModel.canFocus(niri.workspaces, niri.outputName, workspaceId))
            return;
        editingWorkspaceId = workspaceId;
        const globalPos = anchor.mapToItem(null, 0, 0);
        const edge = axis?.edge === "right" ? 3 : 2;
        const pos = SettingsData.getPopupTriggerPosition(globalPos, parentScreen, barThickness, anchor.width, barSpacing,
                                                         edge, barConfig);
        iconPopout.setTriggerPosition(pos.x, pos.y, pos.width, section, parentScreen, edge, barThickness, barSpacing,
                                      barConfig);
        iconPopout.open();
    }

    DankPopout {
        id: iconPopout
        layerNamespace: "dms:justin-navigation-icons"
        popupWidth: 336
        popupHeight: contentLoader.item?.implicitHeight ?? 480
        screen: navigation.parentScreen
        onBackgroundClicked: close()
        content: Component {
            Item {
                // DMS sizes the loaded root to the popup. Keep padding inside it.
                implicitHeight: iconMenu.implicitHeight + Theme.spacingS * 2
                WorkspaceIconMenu {
                    id: iconMenu
                    width: Math.max(0, parent.width - Theme.spacingS * 2)
                    x: Theme.spacingS
                    y: Theme.spacingS
                    currentIcon: WorkspaceModel.iconFor(niri.workspaceIcons, navigation.editingWorkspaceId)
                    pinnedIcons: navigation.pinnedWorkspaceIcons
                    workspaceLabel: "Workspace " + (navigation.editingWorkspace?.idx ?? "")
                    enabled: navigation.editingWorkspace !== null
                    onIconSelected: icon => niri.setWorkspaceIcon(navigation.editingWorkspaceId, icon)
                    onPinToggled: icon => {
                        navigation.pluginService?.savePluginData(navigation.pluginId, "pinnedWorkspaceIcons",
                                                                 WorkspaceModel.togglePin(
                                                                     navigation.pinnedWorkspaceIcons, icon));
                    }
                    Keys.onEscapePressed: iconPopout.close()
                }
            }
        }
    }

    verticalBarPill: Component {
        WorkspaceRail {
            workspaces: niri.outputWorkspaces
            assignments: niri.workspaceIcons
            available: niri.available
            buttonSize: navigation.widgetThickness
            maximumHeight: barGeometry.host !== null ? barGeometry.availableHeight : Math.max(navigation.widgetThickness,
                                                                                              (navigation.parentScreen
                                                                                               ?.height ?? 1080) * 0.6)
            onWorkspaceActivated: workspaceId => niri.focusWorkspace(workspaceId)
            onIconMenuRequested: (workspaceId, anchor) => navigation.openIconMenu(workspaceId, anchor)
        }
    }
}
