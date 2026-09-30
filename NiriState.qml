import QtQuick
import qs.Services
import "WindowModel.js" as WindowModel

// Keep access to DMS's internal compositor services in one place.
// Counts currently cover all outputs, including Niri's trailing empty workspace.
QtObject {
    property string outputName: ""
    readonly property bool available: CompositorService.isNiri
    readonly property var windows: available ? NiriService.windows : []
    readonly property var workspaces: available ? NiriService.allWorkspaces : []
    readonly property int windowCount: windows.length
    readonly property int workspaceCount: workspaces.length
    readonly property var activeWorkspace: WindowModel.activeWorkspace(workspaces, outputName)
    readonly property var currentWindows: WindowModel.workspaceWindows(windows, activeWorkspace)

    function focusWindow(windowId) {
        // Recheck membership in case an old delegate was clicked during an update.
        if (available && currentWindows.some(window => window.id === windowId))
            NiriService.focusWindow(windowId);
    }
}
