import QtQuick
import qs.Services

// Keep access to DMS's internal compositor services in one place.
// Counts currently cover all outputs, including Niri's trailing empty workspace.
QtObject {
    readonly property bool available: CompositorService.isNiri
    readonly property var windows: available ? NiriService.windows : []
    readonly property var workspaces: available ? NiriService.allWorkspaces : []
    readonly property int windowCount: windows.length
    readonly property int workspaceCount: workspaces.length
}
