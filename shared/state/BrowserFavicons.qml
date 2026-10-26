pragma Singleton
import QtQuick
import Quickshell.Io

// One event subscriber shared by every bar instance. No second Niri socket.
QtObject {
    id: favicons
    property var tabs: []
    readonly property string subscriberScript: {
        const url = Qt.resolvedUrl("../scripts/tabctl-favicons.py").toString();
        return decodeURIComponent(url.replace(/^file:\/\//, ""));
    }
    property Process subscriber: Process {
        command: ["/usr/bin/python3", favicons.subscriberScript]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const snapshot = JSON.parse(data);
                    favicons.tabs = Array.isArray(snapshot) ? snapshot : [];
                } catch (error) {
                    favicons.tabs = [];
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("Dux Niri Navigation favicons:", data)
        }
        // Quickshell 0.3.1 metadata omits QProcess::ExitStatus. No arguments are used.
        // qmllint disable signal-handler-parameters
        onExited: {
            favicons.tabs = [];
            favicons.retry.start();
        }
        // qmllint enable signal-handler-parameters
    }
    // Retry a failed subscriber (e.g. missing Python-GObject), not tab polling.
    property Timer retry: Timer {
        interval: 30000
        onTriggered: favicons.subscriber.running = true
    }
}
