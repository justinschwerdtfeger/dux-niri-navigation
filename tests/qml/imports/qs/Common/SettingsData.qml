pragma Singleton
import QtQuick

QtObject {
    property bool reverseScrolling: false
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
