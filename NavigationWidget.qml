pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: navigation

    // DMS 1.6.2 owns the BasePill, but exposes no full-height plugin option.
    // Match by its content component, not child order or the loader hierarchy.
    readonly property var horizontalPillHost: children.find(child =>
        "content" in child && child.content === navigation.horizontalBarPill) ?? null

    Binding {
        target: navigation.horizontalPillHost
        property: "widgetThickness"
        value: navigation.barThickness
        when: navigation.horizontalPillHost !== null && !navigation.isVertical
        restoreMode: Binding.RestoreBindingOrValue
    }

    readonly property real pillPadding: (barConfig?.removeWidgetPadding ?? false)
        ? 0 : (barConfig?.widgetPadding ?? 12) * ((isVertical ? widgetThickness : barThickness) / 30)
    BarGeometry {
        id: barGeometry
        widget: navigation
    }
    // Fall back only while the host is being constructed or is unsupported.
    readonly property real hostWidthLimit: barGeometry.host !== null
        ? Math.max(barThickness, barGeometry.availableWidth)
        : Math.max(barThickness, (parentScreen?.width ?? 1920) - pillPadding * 2)
    readonly property real stripWidth: pluginData.allowFullWidth !== false
        ? hostWidthLimit
        : Math.min(hostWidthLimit, Math.max(240, Number(pluginData.maximumWidth) || 640))

    NiriState {
        id: niri
        outputName: navigation.parentScreen?.name ?? ""
    }

    horizontalBarPill: Component {
        WindowStrip {
            windows: niri.currentWindows
            available: niri.available
            maximumWidth: navigation.stripWidth
            // Match the full-height horizontal BasePill.
            buttonHeight: navigation.barThickness
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
