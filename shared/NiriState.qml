import QtQuick
import qs.Services
import "WindowModel.js" as WindowModel
import "WorkspaceModel.js" as WorkspaceModel
import "BrowserModel.js" as BrowserModel
import "ReorderModel.js" as ReorderModel
import "state" as Session

// Keep access to DMS's internal compositor services in one place.
// All-workspace snapshots also reconcile shared session icons.
QtObject {
    id: state
    property string outputName: ""
    property bool faviconsEnabled: true
    property bool workspaceIconsEnabled: true
    readonly property bool available: CompositorService.isNiri
    readonly property var windows: available ? NiriService.windows : []
    readonly property var workspaces: available ? NiriService.allWorkspaces : []
    readonly property var outputWorkspaces: WorkspaceModel.outputWorkspaces(workspaces, outputName)
    readonly property var workspaceIcons: workspaceIconsEnabled ? Session.WorkspaceIcons.assignments : ({})
    readonly property var activeWorkspace: WindowModel.activeWorkspace(workspaces, outputName)
    readonly property var currentWindows: WindowModel.workspaceWindows(windows, activeWorkspace)
    readonly property var faviconSources: available && faviconsEnabled ? BrowserModel.faviconSources(windows,
                                                                                                     Session.BrowserFavicons.tabs) :
                                                                         ({})
    property var pendingReorder: null
    readonly property bool reorderBusy: pendingReorder !== null
    property Timer reorderTimeout: Timer {
        interval: 1500
        onTriggered: state.cancelReorder()
    }

    function syncWorkspaceIcons() {
        if (workspaceIconsEnabled)
            Session.WorkspaceIcons.sync(workspaces, windows);
    }
    Component.onCompleted: syncWorkspaceIcons()
    onWorkspacesChanged: Qt.callLater(syncWorkspaceIcons)
    onWindowsChanged: {
        Qt.callLater(advanceReorder);
        Qt.callLater(syncWorkspaceIcons);
    }
    onActiveWorkspaceChanged: Qt.callLater(advanceReorder)
    onOutputNameChanged: cancelReorder()
    onAvailableChanged: {
        if (!available)
            cancelReorder();
    }

    function cancelReorder() {
        pendingReorder = null;
        reorderTimeout.stop();
    }

    function reorderWindow(sourceId, targetId, after) {
        cancelReorder();
        pendingReorder = available ? ReorderModel.start(windows, activeWorkspace, sourceId, targetId, after) : null;
        advanceReorder();
    }

    function advanceReorder() {
        if (!pendingReorder)
            return;
        const result = ReorderModel.advance(pendingReorder, windows, available ? activeWorkspace : null);
        if (!result.pending) {
            cancelReorder();
            return;
        }
        pendingReorder = result.pending;
        const request = result.request;
        if (!request)
            return;
        reorderTimeout.restart();
        const accepted = request.focusId !== undefined ? NiriService.focusWindow(request.focusId) : NiriService.send({
                                                                                                                         "Action": {
                                                                                                                             [request.action]:
                                                                                                                             {}
                                                                                                                         }
                                                                                                                     });
        if (!accepted)
            cancelReorder();
        else if (request.focusId !== undefined)
            Qt.callLater(advanceReorder);
    }

    function focusWorkspace(workspaceId) {
        cancelReorder();
        if (available && WorkspaceModel.canFocus(workspaces, outputName, workspaceId))
            NiriService.switchToWorkspace(workspaceId);
    }

    function setWorkspaceIcon(workspaceId, icon) {
        if (available && workspaceIconsEnabled && WorkspaceModel.canFocus(workspaces, outputName, workspaceId))
            Session.WorkspaceIcons.setIcon(workspaceId, icon);
    }

    function scrollColumn(direction) {
        cancelReorder();
        if (!available || !outputName || !activeWorkspace || direction === 0)
            return;
        // DMS focuses this output first when it is not the current output.
        if (direction > 0)
            NiriService.focusColumnRight(outputName);
        else
            NiriService.focusColumnLeft(outputName);
    }

    function focusWindow(windowId) {
        cancelReorder();
        // Recheck membership in case an old delegate was clicked during an update.
        if (available && currentWindows.some(window => window.id === windowId))
            NiriService.focusWindow(windowId);
    }

    function closeWindow(windowId) {
        cancelReorder();
        // Close the clicked window directly, including when it is not focused.
        if (available && windowId !== null && windowId !== undefined && currentWindows.some(window => window.id
                                                                                                      === windowId))

            NiriService.send({
                                 "Action": {
                                     "CloseWindow": {
                                         "id": windowId
                                     }
                                 }
                             });
    }
}
