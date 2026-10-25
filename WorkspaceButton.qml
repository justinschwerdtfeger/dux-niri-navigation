import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DBar

BarPillSurface {
    id: button
    property string iconName: "desktop_windows"
    property string label: ""
    property bool selected: false
    // Picker buttons retain automatic sizing; bar instances use Dux's scale.
    property int iconSize: 0
    // Empty in the icon picker, whose existing grid style is independent.
    property string barStyle: ""
    // Bar delegates can keep the visual inset while reaching the bar edges.
    property real hitWidth: width
    property real hitHeight: height
    signal clicked
    signal rightClicked(var anchor)
    implicitWidth: 36
    implicitHeight: 36
    style: barStyle || "pills"
    radiusOverride: barStyle ? -1 : Theme.cornerRadius
    pressed: barStyle !== "" && pointer.pressed
    color: selected || pointer.containsMouse ? Theme.withAlpha(Theme.primary, pointer.pressed ? 0.25 : 0.12) :
                                               "transparent"
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: enabled
    Accessible.name: label
    Accessible.role: Accessible.Button
    Accessible.focusable: true
    Accessible.onPressAction: {
        if (button.enabled)
            button.clicked();
    }
    Keys.onPressed: event => {
        if (!button.enabled)
            return;
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            button.clicked();
            event.accepted = true;
        } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            button.rightClicked(button);
            event.accepted = true;
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, button.radius - 2)
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: button.activeFocus
    }
    DIcon {
        anchors.centerIn: parent
        name: button.iconName
        size: button.iconSize > 0 ? button.iconSize : Math.max(16, Math.min(button.width, button.height) - 10)
        color: button.selected ? Theme.primary : Theme.surfaceText
    }
    MouseArea {
        id: pointer
        anchors.centerIn: parent
        width: button.hitWidth
        height: button.hitHeight
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: button.forceActiveFocus(Qt.MouseFocusReason)
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                button.rightClicked(button);
            else
                button.clicked();
        }
    }
}
