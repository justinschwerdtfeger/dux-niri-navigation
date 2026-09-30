const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../WindowModel.js'), 'utf8')
    .replace(/^\.pragma library\s*\n/, '');
const model = vm.createContext({});
vm.runInContext(source, model);
const plain = value => JSON.parse(JSON.stringify(value));
const workspace = { id: 10, output: 'DP-1', is_active: true, active_window_id: 2 };
const window = (id, column, row = 1, changes = {}) => ({
    id, workspace_id: 10, title: `Window ${id}`,
    layout: { pos_in_scrolling_layout: [column, row] }, ...changes
});

test('uses the active workspace of the hosting output, independent of global focus', () => {
    const spaces = [workspace, { id: 20, output: 'HDMI-A-1', is_active: true, is_focused: true }];
    assert.equal(model.activeWorkspace(spaces, 'DP-1').id, 10);
    assert.equal(model.activeWorkspace(spaces, 'HDMI-A-1').id, 20);
    assert.equal(model.activeWorkspace(spaces, 'missing'), null);
    assert.equal(model.activeWorkspace(spaces, ''), null);
});

test('filters by workspace and sorts columns then tiles without changing service arrays', () => {
    const input = [window(3, 2), window(2, 1, 2), window(1, 1), window(4, 1, 1, { workspace_id: 20 })];
    const original = JSON.stringify(input);
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [1, 2, 3]);
    assert.equal(JSON.stringify(input), original);
    assert.deepEqual(plain(model.workspaceWindows(input, null)), []);
});

test('places floating and missing or malformed positions after tiled windows with stable ID ordering', () => {
    const input = [window(5, 0, 0, { is_floating: true }), window(4, 0, 0, { layout: {} }),
        window(3, 0, 0, { layout: { pos_in_scrolling_layout: ['bad', 1] } }), window(2, 1)];
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [2, 3, 4, 5]);
});

test('uses the workspace active window and title fallbacks while preserving urgency', () => {
    const input = [window(1, 1, 1, { title: '', app_id: 'org.example.App', is_focused: true }),
        window(2, 2, 1, { title: null, is_urgent: true })];
    const result = plain(model.workspaceWindows(input, workspace));
    assert.equal(result[0].active, false);
    assert.equal(result[0].title, 'Untitled window');
    assert.equal(result[1].active, true);
    assert.equal(result[1].urgent, true);
    assert.equal(result[1].title, 'Untitled window');
});

test('reflects workspace removal, movement, and reordered windows from new snapshots', () => {
    const input = [window(1, 2), window(2, 1)];
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [2, 1]);
    input[0].layout.pos_in_scrolling_layout = [1, 1];
    input[1].workspace_id = 20;
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [1]);
    assert.deepEqual(plain(model.workspaceWindows(input, model.activeWorkspace([], 'DP-1'))), []);
});

test('carries app identity and visual width, preferring decorated tile geometry', () => {
    const result = model.workspaceWindows([
        window(1, 1, 1, { app_id: 'org.gnome.Nautilus', layout: { tile_size: [804, 600], window_size: [800, 596] } }),
        window(2, 2, 1, { layout: { tile_size: [0, 600], window_size: [400, 600] } }),
        window(3, 3, 1, { layout: { tile_size: ['bad', 600], window_size: [-1, 600] } })
    ], workspace);
    assert.equal(result[0].appId, 'org.gnome.Nautilus');
    assert.equal(result[0].visualWidth, 804);
    assert.equal(result[1].visualWidth, 400);
    assert.equal(result[2].visualWidth, null);
});

test('sizes tabs proportionally with a stable monitor scale and variable scroll positions', () => {
    const layout = plain(model.tabGeometry([{ visualWidth: 600 }, { visualWidth: 1200 }], 4, 36, 1800));
    assert.deepEqual(layout.widths, [60, 120]);
    assert.deepEqual(layout.starts, [0, 64]);
    assert.equal(layout.totalWidth, 184);
    const resized = model.tabGeometry([{ visualWidth: 1200 }, { visualWidth: 1200 }], 4, 36, 1800);
    assert.deepEqual(plain(resized.widths), [120, 120]);
});

test('shrinking a tab only clamps that tab and does not enlarge any other tab', () => {
    const before = model.tabGeometry([{ visualWidth: 1000 }, { visualWidth: 2000 }], 4, 64, 2000);
    const after = model.tabGeometry([{ visualWidth: 100 }, { visualWidth: 2000 }], 4, 64, 2000);
    assert.equal(before.widths[0], 90);
    assert.equal(after.widths[0], 64);
    assert.equal(after.widths[1], before.widths[1]);
    assert.equal(after.widths[1], 180);
    assert.ok(after.totalWidth < before.totalWidth);
});

test('adding or removing a small window leaves existing tab widths unchanged', () => {
    const windows = [{ visualWidth: 1000 }, { visualWidth: 2000 }];
    const before = plain(model.tabGeometry(windows, 4, 64, 2000).widths);
    const added = plain(model.tabGeometry([...windows, { visualWidth: 20 }], 4, 64, 2000).widths);
    assert.deepEqual(added.slice(0, 2), before);
    assert.equal(added[2], 64);
    assert.deepEqual(plain(model.tabGeometry(windows.slice(1), 4, 64, 2000).widths), [before[1]]);
});

test('missing geometry uses a stable monitor-wide fallback independent of other sizes', () => {
    const mixed = model.tabGeometry([{ visualWidth: 1000 }, { visualWidth: null }, { visualWidth: 2000 }], 4, 64, 2000);
    assert.deepEqual(plain(mixed.widths), [90, 180, 180]);
    const changed = model.tabGeometry([{ visualWidth: 20 }, { visualWidth: null }], 4, 64, 2000);
    assert.equal(changed.widths[1], mixed.widths[1]);
    const unknown = model.tabGeometry([{ visualWidth: NaN }, { visualWidth: -20 }, {}], 4, 64, 2000);
    assert.deepEqual(plain(unknown.widths), [180, 180, 180]);
    assert.deepEqual(plain(model.tabGeometry([], 4, 64, 2000)), { widths: [], starts: [], totalWidth: 0 });
});

test('uses the exact window title without appending an application name', () => {
    const result = model.workspaceWindows([window(1, 1, 1, { title: 'Budget — June', app_id: 'org.example.Editor' })], workspace);
    assert.equal(result[0].title, 'Budget — June');
});

test('reveals either edge of an active tab and clamps offsets to the content bounds', () => {
    const layout = model.tabGeometry([{ visualWidth: 1800 }, { visualWidth: 1800 },
        { visualWidth: 1800 }], 4, 64, 1800);
    assert.equal(model.scrollPosition(layout, 0, 200, 200, true), 0);
    assert.equal(model.scrollPosition(layout, 2, 0, 200, true), 348);
    assert.equal(model.scrollPosition(layout, 1, 150, 200, true), 164);
    assert.equal(model.scrollPosition(layout, 1, 164, 200, true), 164);
    assert.equal(model.scrollPosition(layout, -1, -20, 200, true), 0);
    assert.equal(model.scrollPosition(layout, -1, 1000, 200, true), 348);
});

test('manual overflow browsing survives updates until active-window following resumes', () => {
    const windows = [{ visualWidth: 1800 }, { visualWidth: 1800 }, { visualWidth: 1800 }];
    const layout = model.tabGeometry(windows, 4, 64, 1800);
    assert.equal(model.scrollPosition(layout, 0, 300, 200, false), 300);
    const resized = model.tabGeometry([...windows, { visualWidth: 300 }], 4, 64, 1800);
    assert.equal(model.scrollPosition(resized, 0, 300, 200, false), 300);
    assert.equal(model.scrollPosition(resized, 0, 300, 200, true), 0);
    const removed = model.tabGeometry(windows.slice(0, 2), 4, 64, 1800);
    assert.equal(model.scrollPosition(removed, 0, 300, 200, false), 164);
});

test('scrolling handles oversized tabs, short content, and empty workspaces', () => {
    const layout = model.tabGeometry([{ visualWidth: 3600 }, { visualWidth: 1800 }], 4, 64, 1800);
    assert.equal(model.scrollPosition(layout, 0, 100, 200, true), 0);
    assert.equal(model.scrollPosition(layout, 0, 100, 200, false), 100);
    assert.equal(model.scrollPosition(layout, 1, 0, 1000, true), 0);
    assert.equal(model.scrollPosition(layout, 9, 100, 200, true), 100);
    assert.equal(model.scrollPosition({ widths: [], starts: [], totalWidth: 0 }, -1, 100, 200, true), 0);
});
