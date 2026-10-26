pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import "WorkspaceModel.js" as WorkspaceModel

NavigationHost {
    id: navigation

    NiriState {
        id: niri
        outputName: navigation.parentScreen?.name ?? ""
        faviconsEnabled: false
    }

    property var editingWorkspaceId: null
    readonly property var editingWorkspace: niri.outputWorkspaces.find(ws => ws.id === editingWorkspaceId) ?? null
    readonly property var pinnedWorkspaceIcons: WorkspaceModel.pinnedIcons(pluginData.pinnedWorkspaceIcons
                                                                           ?? pluginService?.loadPluginData(
                                                                               "justinNavigation",
                                                                               "pinnedWorkspaceIcons", []) ?? [])
    onEditingWorkspaceChanged: {
        if (!editingWorkspace)
            iconPopout.close();
    }

    function openIconMenu(workspaceId, anchor) {
        if (!WorkspaceModel.canFocus(niri.workspaces, niri.outputName, workspaceId))
            return;
        editingWorkspaceId = workspaceId;
        const globalPos = anchor.mapToItem(null, 0, 0);
        const edge = ({
                          top: 0,
                          bottom: 1,
                          left: 2,
                          right: 3
                      })[axis?.edge ?? "top"];
        const pos = SettingsData.getPopupTriggerPosition(globalPos, parentScreen, barThickness, anchor.width, barSpacing,
                                                         edge, barConfig);
        iconPopout.setTriggerPosition(pos.x, pos.y, pos.width, section, parentScreen, edge, barThickness, barSpacing, barConfig,
                                      anchor);
        iconPopout.open();
    }

    DPopout {
        id: iconPopout
        layerNamespace: "dms:justin-workspace-icons"
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

    navigationContent: Component {
        WorkspaceRail {
            id: workspaceRail
            vertical: navigation.isVertical
            workspaces: niri.outputWorkspaces
            assignments: niri.workspaceIcons
            available: niri.available
            buttonSize: navigation.widgetThickness
            crossAxisSize: Math.max(navigation.widgetThickness, navigation.barThickness)
            crossAxisOffset: navigation.contentCrossOffset(workspaceRail)
            barStyle: navigation.barWidgetStyle
            iconSize: navigation.iconSize
            maximumWidth: navigation.primarySizeLimit
            maximumHeight: navigation.primarySizeLimit
            onWorkspaceActivated: workspaceId => niri.focusWorkspace(workspaceId)
            onIconMenuRequested: (workspaceId, anchor) => navigation.openIconMenu(workspaceId, anchor)
        }
    }
}
