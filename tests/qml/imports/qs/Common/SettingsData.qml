pragma Singleton
import QtQuick

QtObject {
    function barWidgetEntry(config, type) {
        for (const key of ["leftWidgets", "centerWidgets", "rightWidgets"]) {
            for (const entry of config?.[key] ?? []) {
                if (entry.id === type)
                    return entry;
            }
        }
        return null;
    }
    function widgetOption(type, entry, key) {
        return entry?.[key] ?? false;
    }
    property var lastPopupPosition: null
    function getPopupTriggerPosition(pos, screen, thickness, width, spacing, edge, config) {
        lastPopupPosition = {
            edge: edge,
            thickness: thickness,
            width: width
        };
        return {
            x: pos.x,
            y: pos.y,
            width: width
        };
    }
}
