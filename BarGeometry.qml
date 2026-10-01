import QtQuick
import "WindowModel.js" as WindowModel

// Internal DMS 1.6.2 host adapter. Keep ancestry/layout assumptions here.
QtObject {
    id: geometry
    required property Item widget

    readonly property var host: findHost()
    readonly property real availableWidth: widget.isVertical ? 0 : availablePrimarySize
    readonly property real availableHeight: widget.isVertical ? availablePrimarySize : 0
    readonly property real availablePrimarySize: {
        if (!host)
            return 0;
        const vertical = widget.isVertical;
        const size = item => vertical ? item.height : item.width;
        const stack = host.section.parent;
        const left = stack.children.find(child => child.objectName === "leftSection");
        const center = stack.children.find(child => child.objectName === "centerSection");
        const right = stack.children.find(child => child.objectName === "rightSection");
        if (!left || !center || !right || size(stack) <= 0)
            return 0;
        // Never read our own section size: it depends on this very budget.
        const siblings = host.layout.children.filter(child =>
            child !== host.wrapper && "itemData" in child && child.visible && size(child) > 0);
        const siblingSizes = siblings.map(size);
        const padding = widget.activePillHost?.horizontalPadding ?? widget.pillPadding;
        return WindowModel.barWidthBudget(size(stack), widget.section,
            widget.section === "left" ? 0 : size(left),
            widget.section === "center" ? 0 : center.contentStart,
            widget.section === "center" ? 0 : center.contentSize,
            widget.section === "right" ? 0 : size(right),
            siblingSizes, host.layout.widgetSpacing, padding);
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
