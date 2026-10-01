.pragma library

// Pure transformations shared by QML and the Node model tests.
// Incremental edits preserve delegates for live IDs across reactive snapshots.
function tabModelChanges(previousIds, nextIds) {
    const ids = previousIds.slice();
    const edits = [];
    for (let index = ids.length - 1; index >= 0; index--) {
        if (!nextIds.includes(ids[index])) {
            edits.push({ type: "remove", index: index });
            ids.splice(index, 1);
        }
    }
    nextIds.forEach((id, index) => {
        const from = ids.indexOf(id);
        if (from < 0) {
            edits.push({ type: "insert", index: index });
            ids.splice(index, 0, id);
        } else if (from !== index) {
            edits.push({ type: "move", from: from, index: index });
            ids.splice(index, 0, ids.splice(from, 1)[0]);
        }
    });
    return edits;
}

function activeWorkspace(workspaces, outputName) {
    if (!outputName)
        return null;
    return workspaces.find(ws => ws.output === outputName && ws.is_active) || null;
}

function tabDropTarget(windows, geometry, sourceId, left) {
    const source = windows.findIndex(window => window.id === sourceId);
    if (source < 0 || windows.length < 2 || !Number.isFinite(left))
        return null;
    let target = source < windows.length - 1
        ? { targetId: windows[source + 1].id, after: false }
        : { targetId: windows[source - 1].id, after: true };
    // Open a gap once the leading edge overlaps 50% of the neighbor.
    // Use original geometry so animated preview positions cannot affect targeting.
    if (left >= geometry.starts[source]) {
        const right = left + geometry.widths[source];
        for (let index = source + 1; index < windows.length; index++) {
            if (right < geometry.starts[index] + geometry.widths[index] * 0.5)
                break;
            target = { targetId: windows[index].id, after: true };
        }
    } else {
        for (let index = source - 1; index >= 0; index--) {
            if (left > geometry.starts[index] + geometry.widths[index] * 0.5)
                break;
            target = { targetId: windows[index].id, after: false };
        }
    }
    return target;
}

function tabDragOffsets(windows, geometry, sourceId, target, gap) {
    const offsets = windows.map(() => 0);
    const source = windows.findIndex(window => window.id === sourceId);
    if (source < 0 || !target)
        return offsets;
    const order = windows.map((window, index) => index).filter(index => index !== source);
    const destination = order.findIndex(index => windows[index].id === target.targetId);
    if (destination < 0)
        return offsets;
    order.splice(destination + (target.after ? 1 : 0), 0, source);
    let start = 0;
    order.forEach(index => {
        offsets[index] = start - geometry.starts[index];
        start += geometry.widths[index] + gap;
    });
    return offsets;
}

// One adjacent swap at a time; the adapter waits for focus/layout events.
function reorderStep(windows, workspace, sourceId, targetId, after) {
    const ordered = workspaceWindows(windows, workspace);
    const ids = ordered.map(window => window.id);
    const source = ids.indexOf(sourceId);
    const target = ids.indexOf(targetId);
    if (source < 0 || target < 0 || source === target)
        return null;
    const destination = target + (after ? 1 : 0) - (source < target ? 1 : 0);
    if (source === destination)
        return { done: true };
    const direction = source < destination ? 1 : -1;
    const neighbor = source + direction;
    const sourceWindow = windows.find(window => window.id === sourceId);
    const neighborWindow = windows.find(window => window.id === ids[neighbor]);
    const a = layoutPosition(sourceWindow);
    const b = layoutPosition(neighborWindow);
    if (![a[0], a[1], b[0], b[1]].every(value => Number.isInteger(value) && value > 0))
        return null;
    const crossColumn = a[0] !== b[0];
    if (crossColumn ? Math.abs(a[0] - b[0]) !== 1 : Math.abs(a[1] - b[1]) !== 1)
        return null;
    const expectedIds = ids.slice();
    [expectedIds[source], expectedIds[neighbor]] = [expectedIds[neighbor], expectedIds[source]];
    return { done: false, neighborId: ids[neighbor], crossColumn: crossColumn,
        action: crossColumn ? (direction > 0 ? "SwapWindowRight" : "SwapWindowLeft")
            : (direction > 0 ? "MoveWindowDown" : "MoveWindowUp"),
        ids: ids, expectedIds: expectedIds };
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

function tabGeometry(windows, gap, minimumWidth, referenceWidth, preferredWidth = 240) {
    if (!windows.length)
        return { widths: [], starts: [], totalWidth: 0 };
    const reference = Number.isFinite(referenceWidth) && referenceWidth > 0 ? referenceWidth : 1920;
    // A monitor-wide window maps to the configured width. Neither the list's average nor its
    // smallest window changes the scale, so unrelated tabs remain stable.
    const preferred = Number.isFinite(preferredWidth) && preferredWidth > 0
        ? Math.max(120, Math.min(480, preferredWidth)) : 240;
    const scale = preferred / reference;
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

// Reserve arrows only after tabs and the launcher exceed the width ceiling.
function stripGeometry(contentWidth, maximumWidth, controlWidth, gap) {
    if (contentWidth <= 0)
        return { width: controlWidth, viewportWidth: 0, showArrows: false };
    const naturalWidth = contentWidth + controlWidth + gap;
    const width = Math.min(maximumWidth, naturalWidth);
    // On an unusually narrow host, keep the launcher and allow dragging
    // rather than placing arrows outside the widget.
    const showArrows = naturalWidth > maximumWidth
        && width > 3 * (controlWidth + gap);
    const controls = showArrows ? 3 : 1;
    return { width: width, showArrows: showArrows,
        viewportWidth: Math.max(0, width - controls * (controlWidth + gap)) };
}

// Bar content width already excludes host frame/inset margins. Only occupied
// sections constrain growth; an empty center's full-size container does not.
function barWidthBudget(barWidth, section, leftWidth, centerStart, centerWidth,
        rightWidth, siblingWidths, gap, padding) {
    let sectionWidth = barWidth;
    if (section === "left") {
        if (rightWidth > 0)
            sectionWidth = Math.min(sectionWidth, barWidth - rightWidth - gap);
        if (centerWidth > 0)
            sectionWidth = Math.min(sectionWidth, centerStart - gap);
    } else if (section === "right") {
        if (leftWidth > 0)
            sectionWidth = Math.min(sectionWidth, barWidth - leftWidth - gap);
        if (centerWidth > 0)
            sectionWidth = Math.min(sectionWidth, barWidth - centerStart - centerWidth - gap);
    } else {
        // A centered section must fit on both sides of the bar midpoint.
        sectionWidth = 2 * Math.max(0, Math.min(
            barWidth / 2 - (leftWidth > 0 ? leftWidth + gap : 0),
            barWidth / 2 - (rightWidth > 0 ? rightWidth + gap : 0)));
    }
    const siblings = siblingWidths.reduce((sum, width) => sum + width, 0);
    return Math.max(0, Math.floor(sectionWidth - siblings
        - siblingWidths.length * gap - padding * 2));
}

// One angle-based notch is always 120 units, even with accompanying pixel data.
function wheelNavigation(previous, angleX, angleY, pixelX, pixelY, reverse, reverseWidget = false) {
    const hasAngle = angleX !== 0 || angleY !== 0;
    const axis = Math.abs(hasAngle ? angleX : pixelX) > Math.abs(hasAngle ? angleY : pixelY) ? "x" : "y";
    const angle = axis === "x" ? angleX : angleY;
    const pixel = axis === "x" ? pixelX : pixelY;
    // Mouse and touchpad angle deltas share units. Switching pixel metadata
    // must not reset partial angle progress or raise the threshold.
    const source = angle !== 0 ? "angle" : pixel !== 0 ? "pixel" : previous.source;
    const delta = source === "pixel" ? pixel : angle;
    const threshold = source === "pixel" ? 50 : 120;
    const value = (previous.axis === axis && previous.source === source ? previous.value : 0) + delta;
    const steps = Math.floor(Math.abs(value) / threshold);
    const direction = steps
        ? (value * (reverse ? -1 : 1) < 0 ? 1 : -1) * (reverseWidget ? -1 : 1) : 0;
    // Retain partial input and every complete step from coalesced wheel events.
    const remainder = value - Math.sign(value) * steps * threshold;
    return { axis: axis, source: source, value: remainder, direction: direction, steps: steps };
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
    return windows.filter(window => window.workspace_id === workspace.id && !window.is_floating)
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
