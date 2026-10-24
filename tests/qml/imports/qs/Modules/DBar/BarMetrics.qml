pragma Singleton
import QtQuick
import qs.Common

// Isolated host boundary: Dux 2.0's bar style and resting/pressed radius contract.
QtObject {
    function widgetStyle(config) {
        return config?.widgetStyle ?? "pills";
    }
    function cornerRadius(thickness, style, joined, progress) {
        const resting = style === "flat" ? Math.min(Theme.cornerRadiusS, thickness / 2) : thickness < 28 ? Math.min(Theme.cornerRadiusM,
                                                                                                                    thickness
                                                                                                                    / 2) : thickness
                                                                                                           / 2;
        const pressed = Math.min(resting, Theme.cornerRadiusS);
        return resting + (pressed - resting) * progress;
    }
}
