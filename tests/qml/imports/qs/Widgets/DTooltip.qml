import QtQuick

Item {
    id: tooltip
    property string text: ""
    property real targetX: 0
    property real targetY: 0
    implicitHeight: 24
    function show(text, x, y, screen, left, right) {
        tooltip.text = text;
        targetX = x;
        targetY = y;
    }
    function hide() {
    }
}
