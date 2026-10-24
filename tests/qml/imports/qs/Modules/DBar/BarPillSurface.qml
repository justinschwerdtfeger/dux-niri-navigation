import QtQuick

Rectangle {
    property real thickness: Math.min(width, height)
    property string style: "pills"
    property bool pressed: false
    property real radiusOverride: -1
    radius: radiusOverride >= 0 ? radiusOverride : BarMetrics.cornerRadius(thickness, style, false, pressed ? 1 : 0)
    topLeftRadius: radius
    topRightRadius: radius
    bottomLeftRadius: radius
    bottomRightRadius: radius
}
