pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import qs.Common
import "../../dist/justinNavigation" as Navigation
import "../../dist/justinNavigation/SidebarModel.js" as SidebarModel

Item {
    id: suite
    width: 700
    height: 600

    Navigation.SidebarView {
        id: sidebar
        width: implicitWidth
        height: 500
        available: true
        hoverOpenDelay: 20
        hoverCloseDelay: 30
        parentScreen: ({
                           name: "DP-1",
                           width: 1920,
                           height: 1080
                       })
        property var activated: []
        property var closed: []
        onWindowActivated: id => activated = activated.concat([id])
        onWindowCloseRequested: id => closed = closed.concat([id])
    }

    function descendants(item, predicate) {
        let result = predicate(item) ? [item] : [];
        for (const child of item.children ?? [])
            result = result.concat(descendants(child, predicate));
        return result;
    }
    function strip() {
        return descendants(sidebar, item => item.objectName === "sidebarWindowStrip")[0];
    }
    function expandButton() {
        return descendants(sidebar, item => item.objectName === "sidebarExpandButton")[0];
    }
    function tabs() {
        return descendants(sidebar, item => "showAppIcon" in item && item.showAppIcon);
    }

    TestCase {
        name: "Sidebar"
        when: windowShown

        function init() {
            Theme.snapListModelChanges = true;
            Theme.fontSizeSmall = 12;
            Theme.shortDuration = 100;
            suite.forceActiveFocus();
            mouseMove(suite, 600, 550);
            sidebar.resetExpansion();
            sidebar.reorderBusy = false;
            sidebar.hoverOpenDelay = 20;
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable"
                                                               }, 1920);
            sidebar.windows = [
                        {
                            id: 1,
                            appId: "",
                            title: "First window",
                            active: true
                        },
                        {
                            id: 2,
                            appId: "",
                            title: "Second window",
                            active: false
                        }
                    ];
            sidebar.activated = [];
            sidebar.closed = [];
            wait(40);
        }

        function test_click_expansion_preserves_buttons_and_interactions() {
            const buttons = suite.tabs();
            compare(sidebar.width, 48);
            compare(buttons[0].showText, false);
            mouseMove(sidebar, 10, 10);
            wait(40);
            compare(sidebar.expanded, false, "click mode ignores hover");
            mouseClick(suite.expandButton());
            compare(sidebar.width, 240);
            compare(sidebar.panelGeometry.reservedWidth, 48);
            compare(suite.tabs()[0], buttons[0]);
            compare(buttons[0].showText, true);
            compare(buttons[0].height, 36);
            mousePress(buttons[0], 50, 18, Qt.LeftButton);
            compare(sidebar.activated[0], 1);
            mouseRelease(buttons[0], 50, 18, Qt.LeftButton);
            compare(sidebar.activated.length, 1);
            mouseClick(buttons[1], 50, 18, Qt.MiddleButton);
            compare(sidebar.closed[0], 2);
            keyClick(Qt.Key_Escape);
            compare(sidebar.expanded, false);
            compare(sidebar.width, 48);
        }

        function test_hover_delays_hold_expansion_through_reorder() {
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarTrigger: "hover"
                                                               }, 1920);
            mouseMove(sidebar, 20, 20);
            compare(sidebar.expanded, false);
            sidebar.reorderBusy = true;
            wait(40);
            compare(sidebar.expanded, false, "opening must also wait for an active gesture or acknowledgment");
            sidebar.reorderBusy = false;
            tryCompare(sidebar, "expanded", true);
            verify(!sidebar.activeFocus && !suite.expandButton().activeFocus, "hover must not acquire keyboard focus");
            sidebar.reorderBusy = true;
            mouseMove(suite, 600, 550);
            wait(60);
            compare(sidebar.expanded, true, "leaving during acknowledgment must not collapse the preview");
            sidebar.reorderBusy = false;
            tryCompare(sidebar, "expanded", false);
            mouseMove(sidebar, 20, 20);
            mouseMove(suite, 600, 550);
            wait(40);
            compare(sidebar.expanded, false, "a brief crossing should not open the sidebar");
        }

        function test_entering_during_acknowledgment_does_not_open() {
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarTrigger: "hover"
                                                               }, 1920);
            sidebar.reorderBusy = true;
            mouseMove(sidebar, 20, 20);
            wait(60);
            compare(sidebar.expanded, false, "entering while held must not arm the open timer");
            sidebar.reorderBusy = false;
            tryCompare(sidebar, "expanded", true);
        }

        function test_expand_button_press_holds_pending_hover() {
            sidebar.hoverOpenDelay = 200;
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarTrigger: "hover"
                                                               }, 1920);
            const button = suite.expandButton();
            mouseMove(button, button.width / 2, button.height / 2);
            mousePress(button, button.width / 2, button.height / 2, Qt.LeftButton);
            try {
                wait(260);
                compare(sidebar.expanded, false, "a held expand button must pause the hover timer");
                verify(button.enabled && button.down, "the button must retain its own press");
            } finally {
                mouseRelease(button, button.width / 2, button.height / 2, Qt.LeftButton);
            }
            compare(sidebar.expanded, true, "release must expand exactly once");
            keyClick(Qt.Key_Escape);
            compare(sidebar.expanded, false);
        }

        function test_launcher_press_holds_hover_expansion() {
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarTrigger: "hover"
                                                               }, 1920);
            mouseMove(sidebar, 20, 20);
            tryCompare(sidebar, "expanded", true);
            const launcher = suite.descendants(sidebar, item => item.tooltip === "Open app launcher")[0];
            mousePress(launcher, launcher.width / 2, launcher.height / 2, Qt.LeftButton);
            try {
                verify(sidebar.interactionHeld, "control presses participate in the interaction hold");
                mouseMove(suite, 600, 550);
                wait(60);
                compare(sidebar.expanded, true, "leaving with a held launcher must not collapse the panel");
            } finally {
                mouseRelease(suite, 600, 550, Qt.LeftButton);
            }
            tryCompare(sidebar, "expanded", false);
        }

        function test_hover_collapse_preserves_overflow_position_and_buttons() {
            Theme.snapListModelChanges = false;
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarTrigger: "hover"
                                                               }, 1920);
            sidebar.windows = Array.from({
                                             length: 30
                                         }, (_, index) => ({
                                             id: index + 1,
                                             appId: "",
                                             title: "Window " + index,
                                             active: index === 0
                                         }));
            mouseMove(sidebar, 20, 20);
            tryCompare(sidebar, "expanded", true);
            wait(Theme.shortDuration + 30);
            const buttons = suite.tabs();
            suite.strip().scrollBy(120);
            compare(suite.strip().scrollOffset, 120);
            mouseMove(suite, 600, 550);
            tryCompare(sidebar, "expanded", false);
            wait(Theme.shortDuration + 30);
            compare(suite.strip().scrollOffset, 120, "collapsing must preserve manual overflow browsing");
            compare(suite.tabs()[1], buttons[1], "collapse must keep delegates");
            mouseMove(sidebar, 20, 20);
            tryCompare(sidebar, "expanded", true);
            wait(Theme.shortDuration + 30);
            compare(suite.strip().scrollOffset, 120, "expanding must preserve manual overflow browsing");
        }

        function test_hover_collapse_keeps_row_and_icon_geometry_stable_data() {
            return [
                        {
                            tag: "default-font",
                            fontSize: 12
                        },
                        {
                            tag: "larger-font",
                            fontSize: 16
                        }
                    ];
        }

        function test_hover_collapse_keeps_row_and_icon_geometry_stable(data) {
            Theme.snapListModelChanges = false;
            Theme.fontSizeSmall = data.fontSize;
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarTrigger: "hover"
                                                               }, 1920);
            mouseMove(sidebar, 20, 20);
            tryCompare(sidebar, "expanded", true);
            wait(Theme.shortDuration + 30);
            const button = suite.tabs()[1];
            const row = button.parent;
            const position = row.visualPosition;
            const iconSize = button.appIconSize;
            compare(row.height, 36);
            let positions = [];
            let iconSizes = [];
            const recordPosition = () => positions.push(row.visualPosition);
            const recordIconSize = () => iconSizes.push(button.appIconSize);
            row.visualPositionChanged.connect(recordPosition);
            button.appIconSizeChanged.connect(recordIconSize);
            try {
                mouseMove(suite, 600, 550);
                tryCompare(sidebar, "expanded", false);
                wait(Theme.shortDuration + 30);
                verify(positions.every(value => Math.abs(value - position) < 0.01), "collapse must not move rows: "
                       + JSON.stringify(positions));
                verify(iconSizes.every(value => value === iconSize), "collapse must not resize/reload icons: "
                       + JSON.stringify(iconSizes));
                compare(suite.tabs()[1], button);
                compare(row.height, 36);
                compare(row.entranceOpacity, 1);
                compare(suite.strip().tabOpacity, 1);
            } finally {
                row.visualPositionChanged.disconnect(recordPosition);
                button.appIconSizeChanged.disconnect(recordIconSize);
            }
        }

        function test_pinned_and_push_geometry_follow_settings() {
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "pinned",
                                                                   sidebarWidth: 300,
                                                                   sidebarSide: "right"
                                                               }, 1920);
            compare(sidebar.width, 300);
            compare(sidebar.panelGeometry.reservedWidth, 300);
            verify(!suite.expandButton().visible);
            compare(suite.tabs()[0].showText, true);
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarPushWindows: true
                                                               }, 1920);
            compare(sidebar.width, 48);
            sidebar.toggleExpansion();
            compare(sidebar.panelGeometry.reservedWidth, 240);
            sidebar.toggleExpansion();
            compare(sidebar.panelGeometry.reservedWidth, 48);
            sidebar.windows = [];
            wait(30);
            compare(suite.strip().windows.length, 0);
            verify(suite.strip().height >= 36, "empty workspaces keep the launcher");
        }

        function test_expansion_animates_width_and_titles_without_moving_icons_data() {
            return [
                        {
                            tag: "overlay-left",
                            push: false,
                            side: "left"
                        },
                        {
                            tag: "push-right",
                            push: true,
                            side: "right"
                        }
                    ];
        }

        function test_expansion_animates_width_and_titles_without_moving_icons(data) {
            Theme.shortDuration = 240;
            sidebar.configuration = SidebarModel.configuration({
                                                                   sidebarMode: "expandable",
                                                                   sidebarPushWindows: data.push,
                                                                   sidebarSide: data.side
                                                               }, 1920);
            Theme.snapListModelChanges = false;
            const button = suite.tabs()[1];
            const iconSize = button.appIconSize;
            const rowPosition = button.parent.visualPosition;
            compare(sidebar.width, 48);
            sidebar.toggleExpansion();
            wait(40);
            verify(sidebar.width > 48 && sidebar.width < 240, "expansion must have intermediate widths");
            verify(button.textOpacity > 0 && button.textOpacity < 1, "titles should fade with the width");
            compare(sidebar.panelGeometry.surfaceWidth, 240);
            compare(sidebar.panelGeometry.reservedWidth, data.push ? 240 : 48);
            compare(button.appIconSize, iconSize);
            compare(button.parent.visualPosition, rowPosition);
            tryCompare(sidebar, "width", 240);
            compare(button.textOpacity, 1);
            sidebar.toggleExpansion();
            wait(40);
            verify(sidebar.width > 48 && sidebar.width < 240, "collapse must also animate");
            compare(sidebar.panelGeometry.surfaceWidth, 240);
            compare(sidebar.panelGeometry.reservedWidth, 48);
            verify(button.showText, "keep fading titles alive while the panel shrinks");
            const reversingWidth = sidebar.width;
            sidebar.toggleExpansion();
            compare(sidebar.width, reversingWidth, "reversing must continue from the current width");
            tryCompare(sidebar, "width", 240);
            compare(suite.tabs()[1], button);
            compare(button.appIconSize, iconSize);
            compare(button.parent.visualPosition, rowPosition);
            Theme.snapListModelChanges = true;
            sidebar.toggleExpansion();
            compare(sidebar.width, 48, "disabled DMS animations must snap immediately");
            compare(button.showText, false);
            compare(button.textOpacity, 0);
        }
    }
}
