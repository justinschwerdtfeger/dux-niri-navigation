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

    Component {
        id: nonbarButtons
        Item {
            property alias navigation: plainNavigation
            property alias workspace: plainWorkspace
            Windows.NavigationButton {
                id: plainNavigation
                width: 120
                height: 36
            }
            Windows.WorkspaceButton {
                id: plainWorkspace
                x: 140
                width: 36
                height: 36
            }
        }
    }

    Component {
        id: budgetFixture
        Item {
            id: bar
            width: 1000
            height: 1000
            property bool vertical: false
            property alias navigation: growingWidget
            property alias sibling: sibling
            property alias center: center
            property alias overflowCount: leading.overflowCount
            Item {
                id: leading
                objectName: "leftSection"
                width: bar.vertical ? 48 : entry.width + sibling.width + widgetSpacing
                height: bar.vertical ? entry.height + sibling.height + widgetSpacing : 48
                property real widgetSpacing: 12
                property int overflowCount: 0
                readonly property real overflowTriggerSize: growingWidget.widgetThickness
                property alias overflowButton: overflowButton
                property QtObject entryRepeater: QtObject {
                    property int count: 2
                    function itemAt(index) {
                        return index === 0 ? entry : sibling;
                    }
                }
                Item {
                    // Dux 2.0's layout Item has no widgetSpacing property.
                    Item {
                        id: entry
                        property var sectionContext: leading
                        property var itemData: ({
                                                    id: "justinNavigation"
                                                })
                        width: growingWidget.width
                        height: growingWidget.height
                        Windows.NavigationWidget {
                            id: growingWidget
                            section: "left"
                            widgetThickness: 30
                            barConfig: ({
                                            widgetPadding: 8
                                        })
                            parentScreen: windows.parentScreen
                            axis: ({
                                       isVertical: bar.vertical,
                                       edge: bar.vertical ? "left" : "top"
                                   })
                        }
                    }
                    Item {
                        id: sibling
                        property var itemData: ({
                                                    id: "clock"
                                                })
                        width: bar.vertical ? 48 : 100
                        height: bar.vertical ? 100 : 48
                    }
                }
                Item {
                    // Native overflow is separate from entryRepeater.
                    id: overflowButton
                    visible: leading.overflowCount > 0
                    width: bar.vertical ? 48 : leading.overflowTriggerSize
                    height: bar.vertical ? leading.overflowTriggerSize : 48
                }
            }
            Item {
                id: center
                objectName: "centerSection"
                width: bar.width
                height: bar.height
                property real contentStart: 400
                property real contentSize: 100
            }
            Item {
                objectName: "rightSection"
                width: bar.vertical ? 48 : 120
                height: bar.vertical ? 120 : 48
            }
        }
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
            windows.widgetThickness = 36;
            windows.barThickness = 48;
            windows.barConfig = null;
            workspaces.axis = {
                isVertical: true,
                edge: "left"
            };
            workspaces.pluginData = {};
            workspaces.widgetThickness = 36;
            workspaces.barThickness = 48;
            workspaces.barConfig = null;
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

        function test_host_thickness_controls_content_on_every_edge_data() {
            const rows = [];
            for (const edge of ["top", "bottom", "left", "right"]) {
                for (const thickness of [28, 40, 48])
                    rows.push({
                                  tag: edge + "-" + thickness,
                                  edge: edge,
                                  thickness: thickness
                              });
            }
            return rows;
        }

        function test_host_thickness_controls_content_on_every_edge(data) {
            const vertical = ["left", "right"].includes(data.edge);
            for (const widget of [windows, workspaces]) {
                widget.axis = {
                    isVertical: vertical,
                    edge: data.edge
                };
                widget.widgetThickness = data.thickness;
                widget.barConfig = {
                    widgetPadding: 6
                };
            }
            wait(30);
            for (const widget of [windows, workspaces]) {
                compare(widget.activePillHost.widgetThickness, data.thickness,
                        "the plugin must preserve the host's thickness binding");
                compare(widget.activePillHost.enableBackgroundHover, false);
                compare(widget.activePillHost.enableCursor, false);
                compare(widget.pillPadding, data.thickness / 5);
                const buttons = suite.descendants(widget, item => widget === windows ? "showAppIcon" in item :
                                                                                       "workspaceId" in item);
                verify(buttons.length > 0);
                for (const button of buttons) {
                    compare(vertical ? button.width : button.height, data.thickness);
                    const pos = button.mapToItem(widget, 0, 0);
                    verify((vertical ? pos.x : pos.y) >= 0);
                    verify((vertical ? pos.x + button.width : pos.y + button.height) <= widget.barThickness);
                }
                widget.barThickness = 60;
                compare(widget.activePillHost.widgetThickness, data.thickness);
                compare(vertical ? buttons[0].width : buttons[0].height, data.thickness,
                        "bar chrome must not enlarge content independently of the host");
                widget.widgetThickness = 32;
                compare(widget.activePillHost.widgetThickness, 32, "host changes stay reactive");
            }
        }

        function test_dux_section_budget_reserves_neighbors_and_padding_data() {
            return [
                        {
                            tag: "horizontal",
                            vertical: false
                        },
                        {
                            tag: "vertical",
                            vertical: true
                        }
                    ];
        }

        function test_dux_section_budget_reserves_neighbors_and_padding(data) {
            const fixture = createTemporaryObject(budgetFixture, suite, {
                                                      vertical: data.vertical
                                                  });
            verify(fixture !== null);
            wait(30);
            // Center starts at 400: leave a gap, the 100 px sibling, a second
            // gap, and 8 px of pill padding on each end. Ignore our own extent.
            compare(fixture.navigation.primarySizeLimit, 260);
            fixture.sibling.visible = false;
            compare(fixture.navigation.primarySizeLimit, 372);
            fixture.center.contentSize = 0;
            compare(fixture.navigation.primarySizeLimit, 852, "an empty center must not constrain growth");
            fixture.navigation.barConfig = {
                widgetPadding: 0
            };
            compare(fixture.navigation.primarySizeLimit, 868, "pill padding is subtracted exactly once");
        }

        function test_dux_section_budget_reserves_native_overflow_data() {
            return test_dux_section_budget_reserves_neighbors_and_padding_data();
        }

        function test_dux_section_budget_reserves_native_overflow(data) {
            NiriService.windows = Array.from({
                                                 length: 40
                                             }, (_, index) => ({
                                                 id: index + 1,
                                                 workspace_id: 10,
                                                 title: "Window " + index,
                                                 layout: {
                                                     pos_in_scrolling_layout: [index + 1, 1]
                                                 }
                                             }));
            const fixture = createTemporaryObject(budgetFixture, suite, {
                                                      vertical: data.vertical
                                                  });
            verify(fixture !== null);
            fixture.sibling.visible = false;
            fixture.center.contentSize = 0;
            fixture.overflowCount = 1;
            // The 1000 px bar reserves the 120 px trailing section, two
            // 12 px gaps, the 30 px overflow trigger, and 16 px pill padding.
            compare(fixture.navigation.primarySizeLimit, 810);
            const primary = data.vertical ? "height" : "width";
            tryCompare(fixture.navigation, primary, 826);
            compare(fixture.navigation[primary] + 30 + 12 + 120 + 12, 1000,
                    "the full strip and native overflow trigger fit beside the trailing section");
            fixture.overflowCount = 2;
            compare(fixture.navigation.primarySizeLimit, 810, "hidden entries share one trigger");
            fixture.overflowCount = 0;
            compare(fixture.navigation.primarySizeLimit, 852, "removing overflow releases the trigger and its gap");
        }

        function test_workspace_edges_remain_clickable_with_inset_data() {
            const rows = [];
            for (const edge of ["top", "bottom", "left", "right"]) {
                for (const thickness of [26, 36])
                    rows.push({
                                  tag: edge + "-" + thickness,
                                  edge: edge,
                                  thickness: thickness
                              });
            }
            return rows;
        }

        function test_workspace_edges_remain_clickable_with_inset(data) {
            const vertical = ["left", "right"].includes(data.edge);
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
                        }
                    ];
            workspaces.axis = {
                isVertical: vertical,
                edge: data.edge
            };
            workspaces.widgetThickness = data.thickness;
            workspaces.barConfig = {
                widgetInset: (48 - data.thickness) / 2
            };
            wait(30);
            const buttons = suite.descendants(workspaces, item => "workspaceId" in item);
            compare(buttons.length, 2);
            const button = buttons[1];
            const center = button.mapToItem(workspaces, button.width / 2, button.height / 2);
            const popout = suite.descendants(workspaces, item => "trigger" in item && "popupWidth" in item)[0];
            for (const cross of [0, workspaces.barThickness - 1]) {
                const x = vertical ? cross : center.x;
                const y = vertical ? center.y : cross;
                NiriService.requests = [];
                mouseClick(workspaces, x, y, Qt.LeftButton);
                compare(NiriService.requests.length, 1, "the inset edge must activate its workspace once");
                compare(NiriService.requests[0].Action.FocusWorkspace.reference.Id, 20);
                mouseClick(workspaces, x, y, Qt.RightButton);
                compare(workspaces.editingWorkspaceId, 20);
                verify(popout.visible, "the inset edge also opens the icon picker");
                compare(NiriService.requests.length, 1, "right click must not switch workspaces");
                popout.close();
            }
            compare(vertical ? button.width : button.height, data.thickness,
                    "full-thickness input must not enlarge the visible button");
            const firstEnd = buttons[0].mapToItem(workspaces, buttons[0].width, buttons[0].height);
            const secondStart = button.mapToItem(workspaces, 0, 0);
            const gap = vertical ? (firstEnd.y + secondStart.y) / 2 : (firstEnd.x + secondStart.x) / 2;
            NiriService.requests = [];
            mouseClick(workspaces, vertical ? 0 : gap, vertical ? gap : 0, Qt.LeftButton);
            compare(NiriService.requests.length, 0, "workspace spacing is not part of either hit target");
            const outside = workspaces.mapToItem(suite, vertical ? workspaces.barThickness + 1 : center.x, vertical
                                                 ? center.y : workspaces.barThickness + 1);
            mouseClick(suite, outside.x, outside.y, Qt.LeftButton);
            compare(NiriService.requests.length, 0, "hit targets stay within the bar thickness");
            compare(suite.descendants(workspaces, item => "workspaceId" in item)[1], button);
        }

        function test_native_icon_and_font_scaling_data() {
            return [
                        {
                            tag: "top",
                            edge: "top",
                            display: "icons"
                        },
                        {
                            tag: "bottom",
                            edge: "bottom",
                            display: "icons"
                        },
                        {
                            tag: "left-icons",
                            edge: "left",
                            display: "icons"
                        },
                        {
                            tag: "right-icons",
                            edge: "right",
                            display: "icons"
                        },
                        {
                            tag: "left-titles",
                            edge: "left",
                            display: "titles"
                        },
                        {
                            tag: "right-rotated",
                            edge: "right",
                            display: "rotated"
                        }
                    ];
        }

        function test_native_icon_and_font_scaling(data) {
            const axis = {
                isVertical: ["left", "right"].includes(data.edge),
                edge: data.edge
            };
            windows.axis = axis;
            windows.pluginData = {
                verticalDisplay: data.display
            };
            workspaces.axis = axis;
            wait(30);
            const tab = suite.descendants(windows, item => "showAppIcon" in item && item.showAppIcon)[0];
            const label = suite.descendants(tab, item => "font" in item && item.text === "Window")[0];
            const workspace = suite.descendants(workspaces, item => "workspaceId" in item)[0];
            const symbol = suite.descendants(workspace, item => "name" in item && "size" in item)[0];
            verify(label !== undefined);
            verify(symbol !== undefined);
            for (const widget of [windows, workspaces])
                widget.barConfig = {
                    iconScale: 1.5,
                    fontScale: 1.5
                };
            compare(tab.appIconSize, 28);
            compare(tab.faviconSize, 23);
            compare(label.font.pixelSize, 18);
            compare(symbol.size, 30);
            const launcher = suite.descendants(windows, item => "acceptMiddleClick" in item && item.text === "+")[0];
            compare(suite.descendants(launcher, item => "font" in item && item.text === "+")[0].font.pixelSize, 18);
            for (const widget of [windows, workspaces])
                widget.barConfig = {
                    iconScale: 1.5,
                    fontScale: 1.5,
                    maximizeWidgetIcons: true,
                    maximizeWidgetText: true
                };
            compare(tab.appIconSize, 40);
            compare(label.font.pixelSize, 24);
            compare(symbol.size, 42);
            wait(30);
            const image = suite.descendants(tab, item => "backer" in item)[0];
            for (const pair of [[windows, image], [workspaces, symbol]]) {
                const viewport = suite.descendants(pair[0], item => "contentX" in item
                                                                    && "flickableDirection" in item)[0];
                const start = pair[1].mapToItem(viewport, 0, 0);
                const end = pair[1].mapToItem(viewport, pair[1].width, pair[1].height);
                verify(Math.min(start.x, end.x) >= -0.01 && Math.max(start.x, end.x) <= viewport.width + 0.01
                       && Math.min(start.y, end.y) >= -0.01 && Math.max(start.y, end.y) <= viewport.height + 0.01,
                       "scaled artwork must fit the viewport at the bar's full thickness: " + data.tag);
            }
            for (const widget of [windows, workspaces]) {
                widget.barConfig = {
                    iconScale: 0.75,
                    fontScale: 0.8
                };
                widget.widgetThickness = 48;
            }
            compare(tab.appIconSize, 14, "inset thickness must not override the requested icon scale");
            compare(label.font.pixelSize, 10);
            compare(symbol.size, 16);
            wait(30);
            compare(suite.descendants(windows, item => "showAppIcon" in item && item.showAppIcon)[0], tab);
            compare(suite.descendants(workspaces, item => "workspaceId" in item)[0], workspace);
        }

        function test_native_bar_rounding_data() {
            return [
                        {
                            tag: "top-pill",
                            edge: "top",
                            style: "pills",
                            thickness: 36,
                            radius: 18
                        },
                        {
                            tag: "top-flat",
                            edge: "top",
                            style: "flat",
                            thickness: 36,
                            radius: 8
                        },
                        {
                            tag: "bottom-segments",
                            edge: "bottom",
                            style: "segments",
                            thickness: 36,
                            radius: 18
                        },
                        {
                            tag: "left-compact",
                            edge: "left",
                            style: "pills",
                            thickness: 26,
                            radius: 12
                        },
                        {
                            tag: "right-flat",
                            edge: "right",
                            style: "flat",
                            thickness: 36,
                            radius: 8
                        },
                        {
                            tag: "right-rotated",
                            edge: "right",
                            style: "pills",
                            thickness: 36,
                            radius: 18
                        }
                    ];
        }

        function test_native_bar_rounding(data) {
            const vertical = ["left", "right"].includes(data.edge);
            windows.pluginData = {
                verticalDisplay: data.tag === "right-rotated" ? "rotated" : "icons"
            };
            for (const widget of [windows, workspaces]) {
                widget.axis = {
                    isVertical: vertical,
                    edge: data.edge
                };
                widget.widgetThickness = data.thickness;
                widget.barConfig = {
                    widgetStyle: data.style
                };
            }
            wait(30);
            const tab = suite.descendants(windows, item => "showAppIcon" in item && item.showAppIcon)[0];
            const workspace = suite.descendants(workspaces, item => "workspaceId" in item)[0];
            const controls = suite.descendants(windows, item => "acceptMiddleClick" in item && !item.showAppIcon);
            for (const button of [tab, workspace, ...controls]) {
                compare(button.radius, data.radius);
                compare(button.topLeftRadius, data.radius);
                compare(button.bottomRightRadius, data.radius);
                const focusRing = suite.descendants(button, item => "border" in item && item.border.width === 2)[0];
                compare(focusRing.radius, Math.max(0, data.radius - 2));
            }
            for (const widget of [windows, workspaces]) {
                widget.widgetThickness = 36;
                widget.barConfig = {
                    widgetStyle: "pills"
                };
            }
            tryCompare(tab, "radius", 18, 1000, "rounding follows host changes without replacing the delegate");
            compare(workspace.radius, 18);
            mousePress(tab, tab.width / 2, tab.height / 2, Qt.LeftButton);
            compare(tab.pressed, true);
            compare(tab.radius, 8, "press state reaches the native bar surface");
            mouseRelease(tab, tab.width / 2, tab.height / 2, Qt.LeftButton);
            compare(tab.radius, 18);
            compare(suite.descendants(windows, item => "showAppIcon" in item && item.showAppIcon)[0], tab);
            compare(suite.descendants(workspaces, item => "workspaceId" in item)[0], workspace);
        }

        function test_nonbar_buttons_retain_generic_rounding() {
            const fixture = createTemporaryObject(nonbarButtons, suite);
            verify(fixture !== null);
            compare(fixture.navigation.barStyle, "");
            compare(fixture.navigation.radius, Math.min(Theme.cornerRadius, 18));
            compare(fixture.workspace.barStyle, "");
            compare(fixture.workspace.radius, Theme.cornerRadius);
            compare(fixture.workspace.hitWidth, fixture.workspace.width, "picker targets keep their own width");
            compare(fixture.workspace.hitHeight, fixture.workspace.height, "picker targets keep their own height");
        }

        function test_scroll_follows_dux_per_bar_workspace_option() {
            const strip = suite.descendants(windows, item => "hostReverseScroll" in item)[0];
            compare(strip.hostReverseScroll, false);
            windows.barConfig = {
                leftWidgets: [
                    {
                        id: "workspaceSwitcher",
                        reverseScrolling: true
                    }
                ]
            };
            compare(strip.hostReverseScroll, true);
            compare(strip.reverseScroll, false);
            windows.pluginData = {
                reverseScroll: true
            };
            compare(strip.hostReverseScroll, true);
            compare(strip.reverseScroll, true);
            windows.barConfig = {
                leftWidgets: []
            };
            compare(strip.hostReverseScroll, false);
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
