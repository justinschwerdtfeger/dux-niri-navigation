import QtQuick
import Quickshell
import qs.Modules.Plugins

PluginSettings {
    pluginId: "justinNavigation"

    ToggleSetting {
        settingKey: "overridePadding"
        label: "Override widget padding"
        description: "Use custom space at both ends of bar widgets instead of the bar's padding."
        defaultValue: false
    }

    SliderSetting {
        settingKey: "widgetPadding"
        label: "Widget padding"
        description:
            "Pixels at each end: left/right on horizontal bars, top/bottom on vertical bars. Requires the override above."
        minimum: 0
        maximum: 48
        defaultValue: 8
        unit: "px"
    }

    SelectionSetting {
        settingKey: "sidebarMode"
        label: "Standalone sidebar"
        description: "A separate DMS panel with its own width. Existing bar widgets remain available."
        options: [
            {
                label: "Off",
                value: "off"
            },
            {
                label: "Always visible titles",
                value: "pinned"
            },
            {
                label: "Expandable icon rail",
                value: "expandable"
            }
        ]
        defaultValue: "off"
    }

    SelectionSetting {
        settingKey: "sidebarSide"
        label: "Sidebar side"
        options: [
            {
                label: "Left",
                value: "left"
            },
            {
                label: "Right",
                value: "right"
            }
        ]
        defaultValue: "left"
    }

    SelectionSetting {
        settingKey: "sidebarOutput"
        label: "Sidebar monitor"
        description: "Unavailable monitors keep their preference without falling back to another output."
        options: [
            {
                label: "All monitors",
                value: "all"
            }
        ].concat(Quickshell.screens.map(screen => ({
            label: screen.name,
            value: screen.name
        })))
        defaultValue: "all"
    }

    SliderSetting {
        settingKey: "sidebarWidth"
        label: "Sidebar title width"
        description: "Width with titles visible, limited to half the monitor. The compact rail is 48 px."
        minimum: 160
        maximum: 480
        defaultValue: 240
        unit: "px"
    }

    SelectionSetting {
        settingKey: "sidebarTrigger"
        label: "Expand sidebar on"
        description: "Hover opens after a short delay. The expand button and Escape are also available."
        options: [
            {
                label: "Click",
                value: "click"
            },
            {
                label: "Hover",
                value: "hover"
            }
        ]
        defaultValue: "click"
    }

    ToggleSetting {
        settingKey: "sidebarPushWindows"
        label: "Push windows aside when expanded"
        description:
            "Expandable mode normally overlays windows beyond the compact rail. Always-visible mode reserves its full width."
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "verticalDisplay"
        label: "Vertical tab display"
        description:
            "Applies to bar widgets. DMS 1.6 limits their width; use the standalone sidebar for normal title rows."
        options: [
            {
                label: "Icons only",
                value: "icons"
            },
            {
                label: "Rotated titles",
                value: "rotated"
            },
            {
                label: "Normal title rows",
                value: "titles"
            }
        ]
        defaultValue: "icons"
    }

    ToggleSetting {
        settingKey: "allowFullWidth"
        label: "Fill available bar space"
        description:
            "Grow along either bar orientation while reserving other widgets. Turn this off to set a smaller maximum below."
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
        label: "Window strip length"
        description: "Maximum width or height when filling available space is off, bounded by the hosting bar."
        minimum: 240
        maximum: 7680
        defaultValue: 640
        unit: "px"
    }
}
