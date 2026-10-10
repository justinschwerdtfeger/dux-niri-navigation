import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: button
    property string iconName: "desktop_windows"
    property string label: ""
    property bool selected: false
    signal clicked
    signal rightClicked(var anchor)
    implicitWidth: 36
    implicitHeight: 36
    radius: Theme.cornerRadius
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
            if (mouse.button === Qt.RightButton)
                button.rightClicked(button);
            else
                button.clicked();
        }
    }
}
