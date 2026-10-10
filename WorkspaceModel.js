.pragma library
// Material Symbols Rounded, rendered by DMS DankIcon in a single theme color.
var icons = [
    'web',
    'terminal',
    'code',
    'folder',
    'chat',
    'mail',
    'music_note',
    'movie',
    'photo',
    'sports_esports',
    'work',
    'school',
    'book',
    'science',
    'draw',
    'palette',
    'dashboard',
    'apps',
    'desktop_windows',
    'home',
    'star',
    'favorite',
    'pets',
    'public',
    'cloud',
    'security',
    'settings',
    'build',
    'bug_report',
    'memory',
    'storage',
    'headphones',
    'videocam',
    'group',
    'calendar_month',
    'shopping_cart',
    'travel_explore',
    'lightbulb',
    'bolt',
    'auto_awesome',
    'diamond',
    'coffee',
    'eco',
    'fitness_center',
    'language',
    'description',
    'calculate',
    'empty_dashboard',
    'laptop',
    'smartphone',
    'tablet',
    'monitor',
    'keyboard',
    'mouse',
    'developer_board',
    'data_object',
    'api',
    'hub',
    'database',
    'account_tree',
    'lan',
    'router',
    'wifi',
    'bluetooth',
    'speaker',
    'radio',
    'mic',
    'library_music',
    'camera',
    'photo_camera',
    'brush',
    'slideshow',
    'live_tv',
    'video_library',
    'forum',
    'call',
    'video_call',
    'contacts',
    'notifications',
    'campaign',
    'event',
    'schedule',
    'timer',
    'checklist',
    'task_alt',
    'note',
    'bookmark',
    'article',
    'explore',
    'map',
    'location_on',
    'directions_bike',
    'directions_car',
    'flight',
    'park',
    'forest',
    'restaurant',
    'celebration',
    'cake',
    'savings',
];

function validIcon(icon) {
    return icons.includes(icon);
}
function pinnedIcons(value) {
    return Array.isArray(value) ? [...new Set(value.filter(validIcon))] : [];
}
function togglePin(value, icon) {
    const pins = pinnedIcons(value);
    return !validIcon(icon)
        ? pins
        : pins.includes(icon)
          ? pins.filter((pin) => pin !== icon)
          : pins.concat([icon]);
}
function outputWorkspaces(workspaces, output) {
    return output
        ? workspaces
              .filter((ws) => ws.output === output)
              .sort((a, b) => a.idx - b.idx || a.id - b.id)
        : [];
}
function canFocus(workspaces, output, id) {
    return !!output && id != null && workspaces.some((ws) => ws.output === output && ws.id === id);
}
function appIcon(appId) {
    const app = String(appId || '').toLowerCase();
    if (/firefox|helium|chromium|chrome|brave|vivaldi|librewolf|zen-browser/.test(app))
        return 'web';
    if (/kitty|alacritty|foot|wezterm|konsole|terminal|ghostty/.test(app)) return 'terminal';
    if (/code|codium|idea|zed|neovim/.test(app)) return 'code';
    if (/nautilus|dolphin|thunar|nemo/.test(app)) return 'folder';
    if (/discord|slack|telegram|signal/.test(app)) return 'chat';
    if (/spotify|rhythmbox|music/.test(app)) return 'music_note';
    return 'desktop_windows';
}
// Seed from the first observed window; on initial loading, lowest ID approximates
// the earliest opened window. Keep the seed even if that window later closes.
function reconcile(previous, workspaces, windows) {
    const firstWindows = new Map();
    for (const window of windows) {
        const first = firstWindows.get(window.workspace_id);
        if (!first || window.id < first.id) firstWindows.set(window.workspace_id, window);
    }
    const next = {};
    let changed = Object.keys(previous).length !== workspaces.length;
    workspaces.forEach((ws) => {
        const key = String(ws.id);
        const old = previous[key];
        const first = firstWindows.get(ws.id);
        const automatic = old?.automatic || (first ? appIcon(first.app_id) : null);
        if (old && old.automatic === automatic) {
            next[key] = old;
        } else {
            next[key] = { automatic: automatic, custom: old?.custom ?? null };
            changed = true;
        }
    });
    return changed ? next : previous;
}
function iconFor(assignments, id) {
    const entry = assignments[String(id)];
    return entry?.custom || entry?.automatic || 'empty_dashboard';
}
function setIcon(assignments, id, icon) {
    if (
        !Object.prototype.hasOwnProperty.call(assignments, String(id)) ||
        (icon !== null && !validIcon(icon))
    )
        return assignments;
    if (assignments[String(id)].custom === icon) return assignments;
    const next = Object.assign({}, assignments);
    next[String(id)] = Object.assign({}, next[String(id)], { custom: icon });
    return next;
}
