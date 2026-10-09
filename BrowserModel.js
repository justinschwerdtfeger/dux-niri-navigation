.pragma library

// Browser IDs and Niri IDs are unrelated. Match only unique active-tab titles
// across ALL outputs/workspaces, never by focus, list position, or saved IDs.
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
        if (!title || helium.filter(other => heliumTitle(other.title) === title).length !== 1)
            continue;
        const matches = tabs.filter(tab => tab.browser === "Helium" && tab.title === title);
        if (matches.length === 1 && typeof matches[0].iconSource === "string")
            sources[window.id] = matches[0].iconSource;
    }
    return sources;
}
