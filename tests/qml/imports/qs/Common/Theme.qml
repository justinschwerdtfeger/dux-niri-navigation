pragma Singleton
import QtQuick

QtObject {
    property int spacingXS: 4
    property int spacingS: 8
    property int cornerRadius: 8
    property int fontSizeSmall: 12
    property int fontSizeMedium: 14
    property int shortDuration: 100
    property int standardEasing: Easing.OutCubic
    property bool snapListModelChanges: true
    property color primary: "#aabbcc"
    property color surfaceText: "white"
    property color surfaceVariantText: "gray"
    property color surfaceContainerHigh: "#202020"
    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }
}
