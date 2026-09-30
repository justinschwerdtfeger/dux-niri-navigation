.pragma library

// Pure transformations shared by QML and the Node model tests.
function activeWorkspace(workspaces, outputName) {
    if (!outputName)
        return null;
    return workspaces.find(ws => ws.output === outputName && ws.is_active) || null;
}

function layoutPosition(window) {
    const pos = window.layout?.pos_in_scrolling_layout;
    if (window.is_floating || !Array.isArray(pos) || pos.length < 2
            || !Number.isFinite(pos[0]) || !Number.isFinite(pos[1]))
        return [Infinity, Infinity];
    return pos;
}

function visualWidth(window) {
    // Niri recommends tile geometry for visual representations (includes borders).
    const tile = window.layout?.tile_size?.[0];
    const client = window.layout?.window_size?.[0];
    return Number.isFinite(tile) && tile > 0 ? tile
        : Number.isFinite(client) && client > 0 ? client : null;
}

function tabGeometry(windows, gap, minimumWidth, referenceWidth) {
    if (!windows.length)
        return { widths: [], starts: [], totalWidth: 0 };
    const reference = Number.isFinite(referenceWidth) && referenceWidth > 0 ? referenceWidth : 1920;
    // A monitor-wide window maps to 180px. Neither the list's average nor its
    // smallest window changes the scale, so unrelated tabs remain stable.
    const scale = 180 / reference;
    const widths = windows.map(w => Math.max(minimumWidth,
        (Number.isFinite(w.visualWidth) && w.visualWidth > 0 ? w.visualWidth : reference) * scale));
    const starts = [];
    let end = 0;
    widths.forEach((width, index) => {
        starts.push(end);
        end += width + (index < widths.length - 1 ? gap : 0);
    });
    return { widths: widths, starts: starts, totalWidth: end };
}

function scrollPosition(layout, activeIndex, offset, viewportWidth, revealActive) {
    const maxOffset = Math.max(0, layout.totalWidth - viewportWidth);
    let next = Math.max(0, Math.min(maxOffset, offset));
    if (revealActive && activeIndex >= 0 && activeIndex < layout.widths.length) {
        const start = layout.starts[activeIndex];
        const width = layout.widths[activeIndex];
        if (start < next)
            next = start;
        else if (start + width > next + viewportWidth)
            next = width > viewportWidth ? start : start + width - viewportWidth;
    }
    return Math.max(0, Math.min(maxOffset, next));
}

function workspaceWindows(windows, workspace) {
    if (!workspace)
        return [];
    return windows.filter(window => window.workspace_id === workspace.id)
        .slice().sort((a, b) => {
            const pa = layoutPosition(a);
            const pb = layoutPosition(b);
            if (pa[0] !== pb[0])
                return pa[0] < pb[0] ? -1 : 1;
            if (pa[1] !== pb[1])
                return pa[1] < pb[1] ? -1 : 1;
            return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
        }).map(window => ({
            id: window.id,
            appId: window.app_id || "",
            visualWidth: visualWidth(window),
            title: window.title || "Untitled window",
            active: workspace.active_window_id != null
                ? window.id === workspace.active_window_id : !!window.is_focused,
            urgent: !!window.is_urgent,
            floating: !!window.is_floating
        }));
}
