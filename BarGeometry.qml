import QtQuick
import "BarModel.js" as BarModel

// Internal Dux 2.0 host adapter. Keep ancestry/layout assumptions here.
QtObject {
    id: geometry
    required property Item widget
    required property bool vertical
    required property string section
    required property real pillPadding
    property var pillHost: null

    function contentCrossOffset(content) {
        // Centered QML loaders round their positions. In particular, a
        // fractional inset need not place content at (bar - widget) / 2.
        // Read each position explicitly so this binding follows resizing and
        // reparenting; mapToItem alone does not track ancestor positions.
        let offset = 0;
        for (let item = content; item && item !== widget; item = item.parent)
            offset += vertical ? item.x : item.y;
        return -offset;
    }

    readonly property var host: findHost(widget)
    readonly property real availablePrimarySize: {
        if (!host)
            return 0;
        const size = item => geometry.vertical ? item.height : item.width;
        const stack = host.section.parent;
        const left = stack.children.find(child => child.objectName === "leftSection");
        const center = stack.children.find(child => child.objectName === "centerSection");
        const right = stack.children.find(child => child.objectName === "rightSection");
        if (!left || !center || !right || size(stack) <= 0)
            return 0;
        // Never read our own section size: it depends on this very budget.
        // Dux increments this as asynchronously incubated entries arrive.
        host.section.entryRevision;
        const repeater = host.section.entryRepeater;
        const entries = Array.from({
                                       length: repeater?.count ?? 0
                                   }, (_, index) => repeater.itemAt(index));
        const siblings = entries.filter(child => child && child !== host.wrapper && "itemData" in child
                                                 && child.visible && size(child) > 0);
        const siblingSizes = siblings.map(size);
        // The native trigger is not a SectionEntry. Use the same extent as
        // Dux's OverflowLayout, even while its button is still incubating.
        if (host.section.overflowCount > 0)
            siblingSizes.push(host.section.overflowTriggerSize);
        const padding = pillHost?.horizontalPadding ?? pillPadding;
        return BarModel.primaryBudget({
                                          length: size(stack),
                                          section,
                                          leading: section === "left" ? 0 : size(left),
                                          centerStart: section === "center" ? 0 : center.contentStart,
                                          center: section === "center" ? 0 : center.contentSize,
                                          trailing: section === "right" ? 0 : size(right),
                                          siblings: siblingSizes,
                                          gap: host.section.widgetSpacing,
                                          padding
                                      });
    }

    function findHost(item) {
        // Both Dux 2.0 side and center sections wrap widgets in SectionEntry.
        while (item) {
            if ("sectionContext" in item && "itemData" in item) {
                return {
                    section: item.sectionContext,
                    wrapper: item
                };
            }
            item = item.parent;
        }
        return null;
    }
}
