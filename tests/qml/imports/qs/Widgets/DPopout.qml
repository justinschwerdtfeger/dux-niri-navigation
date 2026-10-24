pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property string layerNamespace: ""
    property real popupWidth: 0
    property real popupHeight: 0
    property var screen: null
    property Component content: null
    property alias contentLoader: loader
    property var trigger: null
    signal backgroundClicked
    visible: false
    function setTriggerPosition(x, y, width, section, screen, edge, thickness, spacing, config) {
        trigger = {
            x: x,
            y: y,
            width: width,
            edge: edge
        };
    }
    function open() {
        visible = true;
    }
    function close() {
        visible = false;
    }
    Loader {
        id: loader
        width: root.popupWidth
        active: root.visible
        sourceComponent: root.content
    }
}
