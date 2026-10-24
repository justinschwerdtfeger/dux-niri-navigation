pragma Singleton
import QtQuick

QtObject {
    property int spacingXS: 4
    property int spacingS: 8
    property int cornerRadius: 8
    property int cornerRadiusS: 8
    property int cornerRadiusM: 12
    property int fontSizeSmall: 12
    property int fontSizeMedium: 14
    property int fontSizeLarge: 16
    property int fontSizeXLarge: 20
    property int iconSize: 24
    property int iconSizeLarge: 32
    property int shortDuration: 100
    property int standardEasing: Easing.OutCubic
    property bool snapListModelChanges: true
    property color primary: "#aabbcc"
    property color surfaceText: "white"
    property color surfaceVariantText: "gray"
    property color surfaceContainerHigh: "#202020"
    function barIconSize(barThickness, offset, maximizeIcon, iconScale) {
        const defaultOffset = offset !== undefined ? offset : -6;
        const size = (maximizeIcon ?? false) ? iconSizeLarge : iconSize;
        return 2 * Math.round((barThickness / 48) * (size + defaultOffset) * (iconScale ?? 1) / 2);
    }
    function barTextSize(barThickness, fontScale, maximizeText) {
        const scale = barThickness / 48;
        const factor = fontScale ?? 1;
        if (scale <= 0.75)
            return Math.round((maximizeText ? fontSizeMedium : fontSizeSmall * 0.9) * factor);
        if (scale >= 1.25)
            return Math.round((maximizeText ? fontSizeXLarge : fontSizeMedium) * factor);
        return Math.round((maximizeText ? fontSizeLarge : fontSizeSmall) * factor);
    }
    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }
}
