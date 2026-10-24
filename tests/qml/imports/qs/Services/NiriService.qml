pragma Singleton
import QtQuick

QtObject {
    id: service
    property var windows: []
    property var allWorkspaces: []
    property var requests: []
    property bool acceptRequests: true
    function send(request) {
        requests = requests.concat([request]);
        return acceptRequests;
    }
    function focusWindow(id) {
        return send({
                        Action: {
                            FocusWindow: {
                                id: id
                            }
                        }
                    });
    }
    function switchToWorkspace(id) {
        return send({
                        Action: {
                            FocusWorkspace: {
                                reference: {
                                    Id: id
                                }
                            }
                        }
                    });
    }
    function focusColumnLeft(output) {
        return send({
                        output: output,
                        direction: -1
                    });
    }
    function focusColumnRight(output) {
        return send({
                        output: output,
                        direction: 1
                    });
    }
}
