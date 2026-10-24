import qs.Modules.Plugins

PluginSettings {
    pluginId: "justinWorkspaces"

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
}
