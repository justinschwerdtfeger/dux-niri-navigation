pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "ModelUtils.js" as ModelUtils

Item {
    id: rail
    property var workspaces: []
    property var assignments: ({})
    readonly property var activeWorkspaceId: workspaces.find(ws => ws.is_active)?.id ?? null
    property bool available: false
    property real buttonSize: 36
    property real maximumHeight: 600
    signal workspaceActivated(var workspaceId)
    signal iconMenuRequested(var workspaceId, var anchor)
    implicitWidth: buttonSize
    implicitHeight: Math.min(Math.max(0, maximumHeight), list.contentHeight)
    ListModel {
        id: workspaceRows
    }
    function syncModel() {
        ModelUtils.syncRows(workspaceRows, workspaces.map(ws => ({
            workspaceId: ws.id,
            workspaceIndex: ws.idx,
            active: !!ws.is_active
        })), "workspaceId");
    }
    Component.onCompleted: syncModel()
    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: workspaceRows
        spacing: Theme.spacingXS
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: DankScrollbar {}
        delegate: WorkspaceButton {
            required property var workspaceId
            required property int workspaceIndex
            required property bool active
            width: rail.buttonSize
            height: rail.buttonSize
            enabled: rail.available
            iconName: rail.assignments[String(workspaceId)]?.custom || rail.assignments[String(workspaceId)]?.automatic
                      || "empty_dashboard"
            label: "Workspace " + workspaceIndex
            selected: active
            onClicked: rail.workspaceActivated(workspaceId)
            onRightClicked: anchor => rail.iconMenuRequested(workspaceId, anchor)
        }
        function revealActive() {
            const index = rail.workspaces.findIndex(ws => ws.is_active);
            if (index >= 0)
                positionViewAtIndex(index, ListView.Contain);
        }
        onCountChanged: Qt.callLater(revealActive)
        onHeightChanged: Qt.callLater(revealActive)
    }
    onWorkspacesChanged: syncModel()
    onActiveWorkspaceIdChanged: Qt.callLater(list.revealActive)
}
