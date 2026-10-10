import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: "justinNavigation"

    ToggleSetting {
        settingKey: "allowFullWidth"
        label: "Allow full-width growth"
        description:
            "Grow with the window list, reserving space for other bar widgets. Turn this off to set a smaller maximum below."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "reverseScroll"
        label: "Reverse scroll direction"
        description: "Invert DMS's scroll direction when navigating Niri columns over this widget."
        defaultValue: false
    }

    SliderSetting {
        settingKey: "tabWidth"
        label: "Window tab width"
        description:
            "Width for a monitor-wide window. Smaller windows scale proportionally, with a readability minimum."
        minimum: 120
        maximum: 480
        defaultValue: 240
        unit: "px"
    }

    SliderSetting {
        settingKey: "maximumWidth"
        label: "Window strip width"
        description: "Maximum width when full-width growth is off, bounded by available bar space."
        minimum: 240
        maximum: 7680
        defaultValue: 640
        unit: "px"
    }
}
