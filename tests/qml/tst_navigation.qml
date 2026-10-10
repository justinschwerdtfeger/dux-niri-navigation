pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import qs.Common
import qs.Services
import "../.." as Plugin

Item {
    id: suite
    width: 1000
    height: 500

    Plugin.NiriState {
        id: adapter
        outputName: "DP-1"
        faviconsEnabled: false
    }

    Plugin.WindowStrip {
        id: strip
        width: implicitWidth
        buttonHeight: 36
        maximumWidth: 900
        available: true
        property int activations: 0
        property int closes: 0
        onWindowActivated: activations++
        onWindowCloseRequested: closes++
    }

    Plugin.WorkspaceRail {
        id: rail
        y: 100
        available: true
        maximumHeight: 72
        buttonSize: 36
    }

    function descendants(item, predicate) {
        let result = predicate(item) ? [item] : [];
        for (const child of item.children ?? [])
            result = result.concat(descendants(child, predicate));
        return result;
    }

    function tabButtons() {
        return descendants(strip, item => "showAppIcon" in item && item.showAppIcon);
    }

    function windows() {
        return [
                    {
                        id: 1,
                        workspace_id: 10,
                        is_focused: true,
                        title: "One",
                        layout: {
                            pos_in_scrolling_layout: [1, 1]
                        }
                    },
                    {
                        id: 2,
                        workspace_id: 10,
                        title: "Two",
                        layout: {
                            pos_in_scrolling_layout: [2, 1]
                        }
                    }
                ];
    }

    TestCase {
        id: tests
        name: "Navigation"
        when: windowShown

        function init() {
            Theme.snapListModelChanges = true;
            NiriService.acceptRequests = true;
            NiriService.requests = [];
            NiriService.allWorkspaces = [
                        {
                            id: 10,
                            idx: 1,
                            output: "DP-1",
                            is_active: true
                        },
                        {
                            id: 20,
                            idx: 2,
                            output: "DP-1"
                        },
                        {
                            id: 30,
                            idx: 1,
                            output: "DP-2"
                        }
                    ];
            NiriService.windows = suite.windows();
            adapter.cancelReorder();
            adapter.outputName = "DP-1";
            strip.windows = [
                        {
                            id: 1,
                            title: "One",
                            appId: "",
                            active: true
                        },
                        {
                            id: 2,
                            title: "Two",
                            appId: "",
                            active: false
                        }
                    ];
            strip.activations = 0;
            strip.closes = 0;
            rail.workspaces = NiriService.allWorkspaces.filter(ws => ws.output === "DP-1");
            wait(30);
        }

        function cleanup() {
            adapter.cancelReorder();
            Theme.snapListModelChanges = true;
        }

        function test_snapshot_preserves_buttons_and_mouse_timing() {
            const before = suite.tabButtons();
            compare(before.length, 2);
            strip.windows = strip.windows.map(window => Object.assign({}, window, {
                                                                          title: "Updated " + window.id
                                                                      }));
            wait(30);
            const after = suite.tabButtons();
            compare(after[0], before[0]);
            compare(after[1], before[1]);
            compare(after[0].text, "Updated 1");
            mousePress(after[0], 15, 15, Qt.LeftButton);
            compare(strip.activations, 1);
            mouseRelease(after[0], 15, 15, Qt.LeftButton);
            compare(strip.activations, 1);
            mouseClick(after[1], 15, 15, Qt.MiddleButton);
            compare(strip.closes, 1);
            compare(strip.activations, 1);
            after[0].forceActiveFocus();
            keyClick(Qt.Key_Enter);
            compare(strip.activations, 2);
        }

        function test_fitting_growth_and_real_overflow() {
            verify(!strip.showArrows);
            strip.windows = strip.windows.concat([
                                                     {
                                                         id: 3,
                                                         appId: "",
                                                         title: "Three"
                                                     }
                                                 ]);
            wait(30);
            verify(!strip.showArrows);
            strip.maximumWidth = 300;
            wait(30);
            verify(strip.showArrows);
            strip.windows = [];
            wait(30);
            verify(!strip.showArrows);
            compare(strip.implicitWidth, strip.buttonHeight);
            strip.maximumWidth = 900;
        }

        function test_workspace_identity_and_shared_icons() {
            const before = suite.descendants(rail, item => "workspaceId" in item);
            compare(before.length, 2);
            adapter.setWorkspaceIcon(10, "science");
            rail.assignments = adapter.workspaceIcons;
            wait(10);
            compare(before[0].iconName, "science");
            rail.workspaces = rail.workspaces.map(ws => Object.assign({}, ws, {
                                                                          idx: ws.idx + 1
                                                                      }));
            wait(10);
            const after = suite.descendants(rail, item => "workspaceId" in item);
            compare(after[0], before[0]);
            compare(after[0].label, "Workspace 2");
            verify(rail.implicitHeight <= rail.maximumHeight);
            adapter.focusWorkspace(30);
            compare(NiriService.requests.length, 0, "another output is rejected");
        }

        function test_adapter_rejection_and_timeout() {
            NiriService.acceptRequests = false;
            adapter.reorderWindow(1, 2, true);
            verify(!adapter.reorderBusy);
            NiriService.acceptRequests = true;
            NiriService.requests = [];
            adapter.reorderWindow(1, 2, true);
            verify(adapter.reorderBusy);
            compare(NiriService.requests.length, 1);
            wait(1600);
            verify(!adapter.reorderBusy);
            compare(NiriService.requests.length, 1, "no swap without focus acknowledgment");
        }

        function test_drag_acknowledgment_keeps_visual_positions_stable() {
            Theme.snapListModelChanges = false;
            const buttons = suite.tabButtons();
            const first = buttons[0];
            const second = buttons[1];
            const point = first.mapToItem(null, 15, 15);
            strip.startTabDrag(first, 1, point.x, point.y);
            strip.moveTabDrag(first, point.x + 250, point.y);
            wait(130);
            // Hold the accepted preview while the compositor's real row order changes.
            strip.droppedPreview = {
                sourceId: 1,
                target: {
                    targetId: 2,
                    after: true
                }
            };
            strip.cancelTabDrag();
            wait(130);
            const beforeFirst = first.mapToItem(strip, 0, 0).x;
            const beforeSecond = second.mapToItem(strip, 0, 0).x;
            strip.windows = [strip.windows[1], strip.windows[0]];
            for (let frame = 0; frame < 10; frame++) {
                wait(12);
                const firstX = first.mapToItem(strip, 0, 0).x;
                const secondX = second.mapToItem(strip, 0, 0).x;
                verify(Math.abs(firstX - beforeFirst) < 1, "source jumped on acknowledgment");
                verify(Math.abs(secondX - beforeSecond) < 1, "neighbor jumped on acknowledgment");
            }
            strip.droppedPreview = null;
            wait(130);
            verify(first.mapToItem(strip, 0, 0).x > second.mapToItem(strip, 0, 0).x);
        }
    }
}
