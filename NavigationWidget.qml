import QtQuick
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: navigation

    // BasePill adds padding around the content. Reserve basic bar insets too.
    // This is a monitor ceiling, not the space remaining beside other widgets.
    readonly property real pillPadding: (barConfig?.removeWidgetPadding ?? false)
        ? 0 : (barConfig?.widgetPadding ?? 12) * (widgetThickness / 30)
    readonly property real monitorWidthLimit: Math.max(160,
        (parentScreen?.width ?? 1920) - pillPadding * 2
        - Math.max(Theme.spacingXS, (barConfig?.innerPadding ?? 4) * 0.8,
            barConfig?.barInsetPadding ?? 0) * 2)
    readonly property real stripWidth: pluginData.allowFullWidth !== false
        ? monitorWidthLimit
        : Math.min(monitorWidthLimit, Math.max(240, Number(pluginData.maximumWidth) || 640))

    NiriState {
        id: niri
        outputName: navigation.parentScreen?.name ?? ""
    }

    horizontalBarPill: Component {
        WindowStrip {
            windows: niri.currentWindows
            available: niri.available
            maximumWidth: navigation.stripWidth
            buttonHeight: navigation.widgetThickness
            referenceWidth: navigation.parentScreen?.width ?? 1920
            onWindowActivated: windowId => niri.focusWindow(windowId)
            // DMS chooses the launcher's output; this API does not accept a screen.
            onLauncherRequested: PopoutService.openDankLauncherV2()
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "view_sidebar"
                size: Math.max(14, navigation.widgetThickness - 8)
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
