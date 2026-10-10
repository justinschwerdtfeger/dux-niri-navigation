pragma Singleton
import QtQuick

QtObject {
    function moddedAppId(id) {
        return id;
    }
    function getAppName(id, entry) {
        return id;
    }
    function getAppIcon(id, entry) {
        return "";
    }
}
