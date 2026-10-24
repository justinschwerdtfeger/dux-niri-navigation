pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property var axis: null
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 36
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property string pluginId: ""
    property var pluginService: null
    property var pluginData: ({})
    property Component horizontalBarPill: null
    property Component verticalBarPill: null
    readonly property bool isVertical: axis?.isVertical ?? false
    width: isVertical ? verticalPill.width : horizontalPill.width
    height: isVertical ? verticalPill.height : horizontalPill.height

    Item {
        id: horizontalPill
        property Component content: root.horizontalBarPill
        property real widgetThickness: root.widgetThickness
        property real horizontalPadding: 0
        property bool enableBackgroundHover: true
        property bool enableCursor: true
        visible: !root.isVertical
        width: horizontalLoader.item?.implicitWidth ?? 0
        height: horizontalLoader.item?.implicitHeight ?? 0
        Loader {
            id: horizontalLoader
            active: !root.isVertical
            sourceComponent: horizontalPill.content
        }
    }
    Item {
        id: verticalPill
        property Component content: root.verticalBarPill
        property real widgetThickness: root.widgetThickness
        property real horizontalPadding: 0
        property bool enableBackgroundHover: true
        property bool enableCursor: true
        visible: root.isVertical
        width: verticalLoader.item?.implicitWidth ?? 0
        height: verticalLoader.item?.implicitHeight ?? 0
        Loader {
            id: verticalLoader
            active: root.isVertical
            sourceComponent: verticalPill.content
        }
    }
}
