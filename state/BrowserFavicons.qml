pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One event subscriber shared by every bar instance. No second Niri socket.
QtObject {
    id: favicons
    property var tabs: []
    property Process subscriber: Process {
        command: ["/usr/bin/python3", decodeURIComponent(Qt.resolvedUrl("../scripts/tabctl-favicons.py").toString().replace(/^file:\/\//, ""))]
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
            onRead: data => console.warn("Justin Navigation favicons:", data)
        }
        onExited: {
            favicons.tabs = [];
            retry.start();
        }
    }
    // Retry a failed subscriber (e.g. missing Python-GObject), not tab polling.
    property Timer retry: Timer {
        interval: 30000
        onTriggered: favicons.subscriber.running = true
    }
}
