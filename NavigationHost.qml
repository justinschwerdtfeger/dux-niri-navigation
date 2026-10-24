pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.Plugins

PluginComponent {
    id: navigation

    property Component navigationContent: null
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

    // DMS 1.6.2 owns the BasePill, but exposes no full-height plugin option.
    // Match by its content component, not child order or the loader hierarchy.
    readonly property var horizontalPillHost: findPill(horizontalBarPill)

    function findPill(content) {
        return children.find(child => "content" in child && child.content === content) ?? null;
    }

    Binding {
        target: navigation.horizontalPillHost
        property: "widgetThickness"
        value: navigation.barThickness
        when: navigation.horizontalPillHost !== null && !navigation.isVertical
        restoreMode: Binding.RestoreBindingOrValue
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

    readonly property real pillPadding: {
        if (barConfig?.removeWidgetPadding ?? false)
            return 0;
        const thickness = isVertical ? widgetThickness : barThickness;
        return (barConfig?.widgetPadding ?? 12) * thickness / 30;
    }
    BarGeometry {
        id: barGeometry
        widget: navigation
        vertical: navigation.isVertical
        section: navigation.section
        pillPadding: navigation.pillPadding
        pillHost: navigation.activePillHost
    }
    // Bar primary size already excludes the host frame/inset margins.
    readonly property real primarySizeLimit: {
        const thickness = isVertical ? widgetThickness : barThickness;
        const screenSize = isVertical ? (parentScreen?.height ?? 1080) : (parentScreen?.width ?? 1920);
        const available = barGeometry.host !== null ? barGeometry.availablePrimarySize : screenSize - pillPadding * 2;
        return Math.max(thickness, available);
    }
}
