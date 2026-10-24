pragma Singleton
import QtQuick

QtObject {
    property int launches: 0
    function openDankLauncherV2() {
        launches++;
    }
}
