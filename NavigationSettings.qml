import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: "justinNavigation"

    ToggleSetting {
        settingKey: "allowFullWidth"
        label: "Allow full-width growth"
        description: "Let the strip grow up to the monitor width as windows are added. Other bar widgets still need room; turn this off to use the pixel limit below."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "reverseScroll"
        label: "Reverse scroll direction"
        description: "Invert DMS's scroll direction when navigating Niri columns over this widget."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "maximumWidth"
        label: "Window strip width"
        description: "Maximum width when full-width growth is off, bounded by the monitor width."
        minimum: 240
        maximum: 7680
        defaultValue: 640
        unit: "px"
    }
}
