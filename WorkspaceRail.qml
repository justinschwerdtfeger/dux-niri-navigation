pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.DCommon.Widgets
import "ModelUtils.js" as ModelUtils

Item {
    id: rail
    property var workspaces: []
    property var assignments: ({})
    readonly property var activeWorkspaceId: workspaces.find(ws => ws.is_active)?.id ?? null
    property bool available: false
    property bool vertical: true
    property real buttonSize: 36
    property real crossAxisSize: buttonSize
    readonly property real crossAxisPadding: Math.max(0, (crossAxisSize - buttonSize) / 2)
    readonly property real buttonLength: Math.max(buttonSize, iconSize > 0 ? iconSize + 8 : 0)
    property int iconSize: 0
    property string barStyle: ""
    property real maximumHeight: 600
    property real maximumWidth: 600
    signal workspaceActivated(var workspaceId)
    signal iconMenuRequested(var workspaceId, var anchor)
    implicitWidth: vertical ? buttonSize : Math.min(Math.max(0, maximumWidth), list.contentWidth)
    implicitHeight: vertical ? Math.min(Math.max(0, maximumHeight), list.contentHeight) : buttonSize
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
        x: rail.vertical ? -rail.crossAxisPadding : 0
        y: rail.vertical ? 0 : -rail.crossAxisPadding
        width: rail.vertical ? rail.crossAxisSize : rail.width
        height: rail.vertical ? rail.height : rail.crossAxisSize
        clip: true
        model: workspaceRows
        orientation: rail.vertical ? ListView.Vertical : ListView.Horizontal
        spacing: Theme.spacingXS
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: DScrollbar {
            visible: rail.vertical && list.contentHeight > list.height
        }
        ScrollBar.horizontal: DScrollbar {
            visible: !rail.vertical && list.contentWidth > list.width
        }
        delegate: Item {
            id: row
            required property var model
            width: rail.vertical ? rail.crossAxisSize : rail.buttonLength
            height: rail.vertical ? rail.buttonLength : rail.crossAxisSize
            WorkspaceButton {
                readonly property var workspaceId: row.model.workspaceId
                readonly property int workspaceIndex: row.model.workspaceIndex
                readonly property bool active: row.model.active
                anchors.centerIn: parent
                width: rail.vertical ? rail.buttonSize : rail.buttonLength
                height: rail.vertical ? rail.buttonLength : rail.buttonSize
                hitWidth: row.width
                hitHeight: row.height
                enabled: rail.available
                iconName: rail.assignments[String(workspaceId)]?.custom || rail.assignments[String(workspaceId)]
                          ?.automatic || "empty_dashboard"
                label: "Workspace " + workspaceIndex
                selected: active
                iconSize: rail.iconSize
                barStyle: rail.barStyle
                onClicked: rail.workspaceActivated(workspaceId)
                onRightClicked: anchor => rail.iconMenuRequested(workspaceId, anchor)
            }
        }
        function revealActive() {
            const index = rail.workspaces.findIndex(ws => ws.is_active);
            if (index >= 0) {
                // Apply pending delegate size changes before positioning.
                forceLayout();
                positionViewAtIndex(index, ListView.Contain);
            }
        }
        onCountChanged: Qt.callLater(revealActive)
        onHeightChanged: Qt.callLater(revealActive)
        onWidthChanged: Qt.callLater(revealActive)
        onOrientationChanged: Qt.callLater(revealActive)
    }
    onWorkspacesChanged: syncModel()
    onActiveWorkspaceIdChanged: Qt.callLater(list.revealActive)
    onButtonLengthChanged: Qt.callLater(list.revealActive)
}
