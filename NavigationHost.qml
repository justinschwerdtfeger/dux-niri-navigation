pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.Plugins
import qs.Modules.DBar

PluginComponent {
    id: navigation

    property Component navigationContent: null
    readonly property string barWidgetStyle: BarMetrics.widgetStyle(barConfig)
    // Distinct host components let findPill distinguish the two BasePills.
    horizontalBarPill: Component {
        Loader {
            active: !navigation.isVertical
            sourceComponent: navigation.navigationContent
        }
    }
    verticalBarPill: Component {
        Loader {
            active: navigation.isVertical
            sourceComponent: navigation.navigationContent
        }
    }

    // Dux owns pill sizing, including the fork's configurable widget inset.
    readonly property var horizontalPillHost: findPill(horizontalBarPill)

    function findPill(content) {
        return children.find(child => "content" in child && child.content === content) ?? null;
    }

    // Like DMS RunningApps, only the individual buttons are interactive.
    readonly property var verticalPillHost: findPill(verticalBarPill)
    readonly property var activePillHost: isVertical ? verticalPillHost : horizontalPillHost

    Binding {
        target: navigation.activePillHost
        property: "enableBackgroundHover"
        value: false
        when: navigation.activePillHost !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: navigation.activePillHost
        property: "enableCursor"
        value: false
        when: navigation.activePillHost !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    readonly property real pillPadding: activePillHost?.horizontalPadding ?? (barConfig?.widgetPadding ?? 8)
                                        * widgetThickness / 30
    BarGeometry {
        id: barGeometry
        widget: navigation
        vertical: navigation.isVertical
        section: navigation.section
        pillPadding: navigation.pillPadding
        pillHost: navigation.activePillHost
    }
    function contentCrossOffset(content) {
        return barGeometry.contentCrossOffset(content);
    }
    // Bar primary size already excludes the host frame/inset margins.
    readonly property real primarySizeLimit: {
        const thickness = widgetThickness;
        const screenSize = isVertical ? (parentScreen?.height ?? 1080) : (parentScreen?.width ?? 1920);
        const available = barGeometry.host !== null ? barGeometry.availablePrimarySize : screenSize - pillPadding * 2;
        return Math.max(thickness, available);
    }
}
