import QtQuick

// Never launches a process in the isolated suite.
QtObject {
    property var command: []
    property bool running: false
    property QtObject stdout
    property QtObject stderr
    signal exited(int exitCode, int exitStatus)
}
