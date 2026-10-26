.pragma library
// Browser IDs and Niri IDs are unrelated. Use title matches across ALL
// outputs/workspaces only when every candidate agrees on a nonempty icon.
// This assigns artwork, never browser-window identity or a saved association.
function heliumTitle(title) {
    return typeof title === 'string' ? title.replace(/ - Helium$/, '') : '';
}

function faviconSources(windows, tabs) {
    const sources = {};
    if (!Array.isArray(windows) || !Array.isArray(tabs)) return sources;
    const candidates = new Map();
    for (const tab of tabs) {
        if (tab.browser !== 'Helium' || !tab.title) continue;
        const source = typeof tab.iconSource === 'string' ? tab.iconSource : '';
        // Once a title is ambiguous or incomplete, later candidates cannot
        // make it safe. Map handles arbitrary titles, including '__proto__'.
        candidates.set(
            tab.title,
            !candidates.has(tab.title) || candidates.get(tab.title) === source ? source : '',
        );
    }
    for (const window of windows) {
        if (window.app_id !== 'helium') continue;
        const title = heliumTitle(window.title);
        const source = candidates.get(title);
        if (source) sources[window.id] = source;
    }
    return sources;
}
