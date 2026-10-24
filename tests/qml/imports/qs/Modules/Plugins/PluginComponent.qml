pragma ComponentBehavior: Bound
import QtQuick
import qs.Common

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
    property int backgroundPressCount: 0
    readonly property int iconSize: Theme.barIconSize(barThickness, -4, barConfig?.maximizeWidgetIcons, barConfig
                                                      ?.iconScale)
    readonly property int iconSizeLarge: Theme.barIconSize(barThickness, undefined, barConfig?.maximizeWidgetIcons,
                                                           barConfig?.iconScale)
    readonly property int textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    readonly property bool isVertical: axis?.isVertical ?? false
    width: isVertical ? verticalPill.width : horizontalPill.width
    height: isVertical ? verticalPill.height : horizontalPill.height

    Item {
        id: horizontalPill
        property Component content: root.horizontalBarPill
        property real widgetThickness: root.widgetThickness
        readonly property real horizontalPadding: (root.barConfig?.widgetPadding ?? 8) * widgetThickness / 30
        property bool enableBackgroundHover: true
        property bool enableCursor: true
        visible: !root.isVertical
        readonly property real visualWidth: (horizontalLoader.item?.implicitWidth ?? 0) + horizontalPadding * 2
        readonly property real visualHeight: widgetThickness
        width: visualWidth
        height: root.barThickness
        Item {
            width: horizontalPill.visualWidth
            height: horizontalPill.visualHeight
            anchors.centerIn: parent
            Loader {
                id: horizontalLoader
                anchors.centerIn: parent
                active: !root.isVertical
                sourceComponent: horizontalPill.content
            }
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: root.backgroundPressCount++
        }
    }
    Item {
        id: verticalPill
        property Component content: root.verticalBarPill
        property real widgetThickness: root.widgetThickness
        readonly property real horizontalPadding: (root.barConfig?.widgetPadding ?? 8) * widgetThickness / 30
        property bool enableBackgroundHover: true
        property bool enableCursor: true
        visible: root.isVertical
        readonly property real visualWidth: widgetThickness
        readonly property real visualHeight: (verticalLoader.item?.implicitHeight ?? 0) + horizontalPadding * 2
        width: root.barThickness
        height: visualHeight
        Item {
            width: verticalPill.visualWidth
            height: verticalPill.visualHeight
            anchors.centerIn: parent
            Loader {
                id: verticalLoader
                anchors.centerIn: parent
                active: root.isVertical
                sourceComponent: verticalPill.content
            }
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: root.backgroundPressCount++
        }
    }
}
