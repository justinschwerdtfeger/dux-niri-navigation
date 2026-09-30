import QtQuick
import qs.Modules.Plugins

PluginSettings {
    StringSetting {
        settingKey: "label"
        label: "Widget label"
        description: "Label for the initial horizontal navigation widget."
        placeholder: "Navigation"
        defaultValue: "Navigation"
    }
}
