.pragma library

// Browser IDs and Niri IDs are unrelated. Use title matches across ALL
// outputs/workspaces only when every candidate agrees on a nonempty icon.
// This assigns artwork, never browser-window identity or a saved association.
function heliumTitle(title) {
    return typeof title === "string" ? title.replace(/ - Helium$/, "") : "";
}

function faviconSources(windows, tabs) {
    const sources = {};
    if (!Array.isArray(windows) || !Array.isArray(tabs))
        return sources;
    const helium = windows.filter(window => window.app_id === "helium");
    for (const window of helium) {
        const title = heliumTitle(window.title);
        if (!title)
            continue;
        const matches = tabs.filter(tab => tab.browser === "Helium" && tab.title === title);
        const source = matches.length > 0 ? matches[0].iconSource : "";
        if (typeof source === "string" && source.length > 0
                && matches.every(tab => tab.iconSource === source))
            sources[window.id] = source;
    }
    return sources;
}
