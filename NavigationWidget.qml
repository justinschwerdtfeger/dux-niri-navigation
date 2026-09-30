import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: navigation

    layerNamespacePlugin: "justin-navigation"

    readonly property string label: pluginData.label ?? "Navigation"

    NiriState {
        id: niri
    }

    // A diagnostic starting point, not the finished window strip or workspace rail.
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "view_sidebar"
                size: navigation.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: navigation.label
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: niri.available
                    ? niri.windowCount + " windows · " + niri.workspaceCount + " spaces"
                    : "Niri required"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "view_sidebar"
                size: navigation.iconSize
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: niri.available ? String(niri.workspaceCount) : "—"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
