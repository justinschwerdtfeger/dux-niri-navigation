pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import qs.Common
import qs.Services
import "../.." as Windows
import "../../workspace-plugin" as Workspaces

Item {
    id: suite
    width: 1000
    height: 800

    QtObject {
        id: settings
        property var writes: []
        function loadPluginData(plugin, key, fallback) {
            return ["science", "home"];
        }
        function savePluginData(plugin, key, value) {
            writes = writes.concat([
                                       {
                                           plugin: plugin,
                                           key: key,
                                           value: value
                                       }
                                   ]);
        }
    }

    Windows.NavigationWidget {
        id: windows
        pluginId: "justinNavigation"
        pluginService: settings
        parentScreen: ({
                           name: "DP-1",
                           width: 1920,
                           height: 1080
                       })
        axis: ({
                   isVertical: false,
                   edge: "top"
               })
    }

    Workspaces.Widget {
        id: workspaces
        y: 550
        pluginId: "justinWorkspaces"
        pluginService: settings
        parentScreen: windows.parentScreen
        axis: ({
                   isVertical: true,
                   edge: "left"
               })
    }

    function descendants(item, predicate) {
        let result = predicate(item) ? [item] : [];
        for (const child of item.children ?? [])
            result = result.concat(descendants(child, predicate));
        return result;
    }

    TestCase {
        name: "Plugins"
        when: windowShown

        function init() {
            Theme.snapListModelChanges = true;
            NiriService.allWorkspaces = [
                        {
                            id: 10,
                            idx: 1,
                            output: "DP-1",
                            is_active: true
                        }
                    ];
            NiriService.windows = [
                        {
                            id: 1,
                            workspace_id: 10,
                            app_id: "",
                            title: "Window",
                            is_focused: true
                        }
                    ];
            windows.axis = {
                isVertical: false,
                edge: "top"
            };
            windows.pluginData = {};
            workspaces.axis = {
                isVertical: true,
                edge: "left"
            };
            workspaces.pluginData = {};
            settings.writes = [];
            wait(30);
        }

        function test_each_plugin_keeps_its_role_when_orientation_changes() {
            verify(windows.width > windows.height);
            verify(windows.horizontalPillHost !== windows.verticalPillHost);
            compare(windows.activePillHost, windows.horizontalPillHost);
            verify(suite.descendants(windows, item => "showAppIcon" in item && item.showAppIcon).length > 0);
            windows.pluginData = {
                verticalDisplay: "rotated"
            };
            windows.axis = {
                isVertical: true,
                edge: "right"
            };
            workspaces.axis = {
                isVertical: false,
                edge: "bottom"
            };
            wait(30);
            verify(windows.height > windows.width);
            compare(windows.activePillHost, windows.verticalPillHost);
            verify(workspaces.horizontalPillHost !== workspaces.verticalPillHost);
            compare(workspaces.activePillHost, workspaces.horizontalPillHost);
            const windowButtons = suite.descendants(windows, item => "showAppIcon" in item && item.showAppIcon);
            compare(windowButtons[0].rotation, -90);
            const workspaceButtons = suite.descendants(workspaces, item => "workspaceId" in item);
            compare(workspaceButtons.length, 1);
        }

        function test_picker_edges_and_legacy_favorites() {
            compare(workspaces.pinnedWorkspaceIcons.length, 2);
            workspaces.pluginData = {
                pinnedWorkspaceIcons: []
            };
            compare(workspaces.pinnedWorkspaceIcons.length, 0, "an explicit empty list overrides legacy favorites");
            for (const [edge, position] of [["top", 0], ["bottom", 1], ["left", 2], ["right", 3]]) {
                workspaces.axis = {
                    isVertical: position >= 2,
                    edge: edge
                };
                wait(30);
                const buttons = suite.descendants(workspaces, item => "workspaceId" in item);
                workspaces.openIconMenu(10, buttons[0]);
                compare(SettingsData.lastPopupPosition.edge, position);
                const popout = suite.descendants(workspaces, item => "trigger" in item && "popupWidth" in item)[0];
                compare(popout.trigger.edge, position);
                popout.close();
            }
            workspaces.openIconMenu(99, workspaces);
            compare(workspaces.editingWorkspaceId, 10, "stale workspace IDs are rejected");
        }
    }
}
