pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "SidebarModel.js" as SidebarModel

Item {
    id: daemon

    property string pluginId: "justinNavigation"
    property var pluginService: null
    readonly property var pluginData: SettingsData.getPluginSettingsForPlugin(pluginId)

    function toggle() {
        for (const panel of panels.instances)
            panel.toggleExpansion();
    }

    Variants {
        id: panels
        model: SidebarModel.outputs(Quickshell.screens, daemon.pluginData)
        delegate: SidebarPanel {
            required property var modelData
            screen: modelData
            pluginData: daemon.pluginData
        }
    }
}
