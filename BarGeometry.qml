import QtQuick
import "WindowModel.js" as WindowModel

// Internal DMS 1.6.2 host adapter. Keep ancestry/layout assumptions here.
QtObject {
    id: geometry
    required property Item widget

    readonly property var host: findHost()
    readonly property real availableWidth: {
        if (!host || widget.isVertical)
            return 0;
        const stack = host.section.parent;
        const left = stack.children.find(child => child.objectName === "leftSection");
        const center = stack.children.find(child => child.objectName === "centerSection");
        const right = stack.children.find(child => child.objectName === "rightSection");
        if (!left || !center || !right || stack.width <= 0)
            return 0;
        // Never read our own section width: it depends on this very budget.
        const siblings = host.layout.children.filter(child =>
            child !== host.wrapper && "itemData" in child && child.visible && child.width > 0);
        const siblingWidths = siblings.map(child => child.width);
        const padding = widget.horizontalPillHost?.horizontalPadding ?? widget.pillPadding;
        return WindowModel.barWidthBudget(stack.width, widget.section,
            widget.section === "left" ? 0 : left.width,
            widget.section === "center" ? 0 : center.contentStart,
            widget.section === "center" ? 0 : center.contentSize,
            widget.section === "right" ? 0 : right.width,
            siblingWidths, host.layout.widgetSpacing, padding);
    }

    function findHost() {
        let item = widget;
        let wrapper = null;
        let layout = null;
        while (item && item.parent) {
            const parent = item.parent;
            if (!layout && "widgetSpacing" in parent) {
                layout = parent;
                wrapper = item;
            }
            if (["leftSection", "centerSection", "rightSection"].includes(parent.objectName)) {
                // CenterSection lays delegates out directly rather than in a Row.
                return { section: parent, layout: layout ?? parent,
                    wrapper: wrapper ?? item };
            }
            item = parent;
        }
        return null;
    }
}
