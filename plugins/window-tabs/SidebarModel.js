.pragma library
function configuration(data, screenWidth) {
    const mode = ['pinned', 'expandable'].includes(data.sidebarMode) ? data.sidebarMode : 'off';
    const requested = Number(data.sidebarWidth);
    const width = Number.isFinite(requested) && requested > 0 ? requested : 240;
    const available = Number.isFinite(screenWidth) && screenWidth > 0 ? screenWidth : 1920;
    return {
        mode,
        side: data.sidebarSide === 'right' ? 'right' : 'left',
        width: Math.round(
            Math.min(Math.max(160, Math.min(480, width)), Math.max(48, available / 2)),
        ),
        compactWidth: 48,
        trigger: data.sidebarTrigger === 'hover' ? 'hover' : 'click',
        pushWindows: data.sidebarPushWindows === true,
    };
}

function geometry(config, expanded, displayWidth) {
    const showTitles = config.mode === 'pinned' || (config.mode === 'expandable' && expanded);
    const targetWidth = showTitles ? config.width : config.compactWidth;
    const width = Number.isFinite(displayWidth)
        ? Math.max(config.compactWidth, Math.min(config.width, displayWidth))
        : targetWidth;
    return {
        showTitles,
        width,
        surfaceWidth: config.width,
        reservedWidth:
            config.mode === 'off'
                ? 0
                : config.pushWindows || config.mode === 'pinned'
                  ? targetWidth
                  : config.compactWidth,
    };
}

function outputs(screens, data) {
    if (!['pinned', 'expandable'].includes(data.sidebarMode)) return [];
    const output = data.sidebarOutput || 'all';
    return screens.filter((screen) => output === 'all' || screen.name === output);
}
