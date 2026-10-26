pragma Singleton
import QtQuick
import "../WorkspaceModel.js" as WorkspaceModel

// Shared ephemeral assignments. No runtime workspace IDs are written to disk.
QtObject {
    property var assignments: ({})
    function sync(workspaces, windows) {
        const next = WorkspaceModel.reconcile(assignments, workspaces, windows);
        if (next !== assignments)
            assignments = next;
    }
    function setIcon(workspaceId, icon) {
        assignments = WorkspaceModel.setIcon(assignments, workspaceId, icon);
    }
}
