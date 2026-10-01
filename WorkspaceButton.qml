import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: button
    property string iconName: "desktop_windows"
    property string label: ""
    property bool selected: false
    signal clicked()
    signal rightClicked(var anchor)
    implicitWidth: 36
    implicitHeight: 36
    radius: Theme.cornerRadius
    color: selected || pointer.containsMouse ? Theme.withAlpha(Theme.primary, pointer.pressed ? 0.25 : 0.12) : "transparent"
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Accessible.name: label
    Accessible.role: Accessible.Button
    Accessible.onPressAction: { if (button.enabled) button.clicked(); }
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            button.rightClicked(button);
            event.accepted = true;
        }
    }
    DankIcon {
        anchors.centerIn: parent
        name: button.iconName
        size: Math.max(16, Math.min(button.width, button.height) - 10)
        color: button.selected ? Theme.primary : Theme.surfaceText
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) button.rightClicked(button);
            else button.clicked();
        }
    }
}
