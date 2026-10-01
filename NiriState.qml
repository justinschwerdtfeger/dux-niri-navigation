import QtQuick
import qs.Services
import "WindowModel.js" as WindowModel
import "WorkspaceModel.js" as WorkspaceModel
import "state" as Session

// Keep access to DMS's internal compositor services in one place.
// All-workspace snapshots also reconcile shared session icons.
QtObject {
    id: state
    property string outputName: ""
    readonly property bool available: CompositorService.isNiri
    readonly property var windows: available ? NiriService.windows : []
    readonly property var workspaces: available ? NiriService.allWorkspaces : []
    readonly property var outputWorkspaces: WorkspaceModel.outputWorkspaces(workspaces, outputName)
    readonly property var workspaceIcons: Session.WorkspaceIcons.assignments
    readonly property int windowCount: windows.length
    readonly property int workspaceCount: workspaces.length
    readonly property var activeWorkspace: WindowModel.activeWorkspace(workspaces, outputName)
    readonly property var currentWindows: WindowModel.workspaceWindows(windows, activeWorkspace)
    property var pendingReorder: null
    readonly property bool reorderBusy: pendingReorder !== null
    property Timer reorderTimeout: Timer {
        interval: 1500
        onTriggered: state.cancelReorder()
    }

    function syncWorkspaceIcons() { Session.WorkspaceIcons.sync(workspaces, windows); }
    Component.onCompleted: syncWorkspaceIcons()
    onWorkspacesChanged: Qt.callLater(syncWorkspaceIcons)
    onWindowsChanged: { Qt.callLater(advanceReorder); Qt.callLater(syncWorkspaceIcons); }
    onActiveWorkspaceChanged: Qt.callLater(advanceReorder)
    onOutputNameChanged: cancelReorder()
    onAvailableChanged: { if (!available) cancelReorder(); }

    function cancelReorder() {
        pendingReorder = null;
        reorderTimeout.stop();
    }

    function reorderWindow(sourceId, targetId, after) {
        cancelReorder();
        const step = available
            ? WindowModel.reorderStep(windows, activeWorkspace, sourceId, targetId, after) : null;
        if (!step || step.done)
            return;
        pendingReorder = { sourceId: sourceId, targetId: targetId, after: after,
            workspaceId: activeWorkspace.id, stage: "next", step: null };
        advanceReorder();
    }

    function awaitFocus(windowId, stage) {
        pendingReorder.stage = stage;
        reorderTimeout.restart();
        if (!NiriService.focusWindow(windowId)) {
            cancelReorder();
            return;
        }
        Qt.callLater(advanceReorder);
    }

    function advanceReorder() {
        const pending = pendingReorder;
        if (!pending)
            return;
        if (!available || !activeWorkspace || activeWorkspace.id !== pending.workspaceId
                || !currentWindows.some(window => window.id === pending.sourceId)
                || !currentWindows.some(window => window.id === pending.targetId)) {
            cancelReorder();
            return;
        }
        const ids = currentWindows.map(window => window.id);
        const sameIds = other => ids.length === other.length && ids.every((id, i) => id === other[i]);
        const focusedId = windows.find(window => window.is_focused)?.id ?? null;
        if (pending.stage === "layout") {
            if (sameIds(pending.step.expectedIds)) {
                pending.stage = "next";
            } else {
                if (!sameIds(pending.step.ids) || (focusedId !== null && focusedId !== pending.sourceId))
                    cancelReorder();
                return;
            }
        }
        if (pending.stage === "next") {
            const step = WindowModel.reorderStep(windows, activeWorkspace,
                pending.sourceId, pending.targetId, pending.after);
            if (!step || step.done) {
                cancelReorder();
                return;
            }
            pending.step = step;
            awaitFocus(step.crossColumn ? step.neighborId : pending.sourceId,
                step.crossColumn ? "neighborFocus" : "sourceFocus");
            return;
        }
        if (!sameIds(pending.step.ids)) {
            cancelReorder();
            return;
        }
        const latest = WindowModel.reorderStep(windows, activeWorkspace,
            pending.sourceId, pending.targetId, pending.after);
        if (!latest || latest.done || latest.action !== pending.step.action
                || latest.neighborId !== pending.step.neighborId) {
            cancelReorder();
            return;
        }
        if (pending.stage === "neighborFocus" && focusedId === pending.step.neighborId) {
            // Niri swaps with the adjacent column's active tile. Select it first.
            awaitFocus(pending.sourceId, "sourceFocus");
        } else if (pending.stage === "sourceFocus" && focusedId === pending.sourceId) {
            pending.stage = "layout";
            reorderTimeout.restart();
            const action = {};
            action[pending.step.action] = {};
            if (!NiriService.send({ "Action": action }))
                cancelReorder();
        }
    }

    function focusWorkspace(workspaceId) {
        cancelReorder();
        if (available && WorkspaceModel.canFocus(workspaces, outputName, workspaceId))
            NiriService.switchToWorkspace(workspaceId);
    }

    function setWorkspaceIcon(workspaceId, icon) {
        if (available && WorkspaceModel.canFocus(workspaces, outputName, workspaceId))
            Session.WorkspaceIcons.setIcon(workspaceId, icon);
    }

    function scrollColumn(direction) {
        cancelReorder();
        if (!available || !outputName || !activeWorkspace || direction === 0)
            return;
        // DMS focuses this output first when it is not the current output.
        if (direction > 0)
            NiriService.moveColumnRight(outputName);
        else
            NiriService.moveColumnLeft(outputName);
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
        if (available && windowId !== null && windowId !== undefined
                && currentWindows.some(window => window.id === windowId))
            NiriService.send({ "Action": { "CloseWindow": { "id": windowId } } });
    }
}
