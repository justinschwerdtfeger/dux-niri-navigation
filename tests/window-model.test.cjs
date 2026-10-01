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

test('excludes floating windows and orders positionless tiled windows by ID', () => {
    const input = [window(5, 0, 0, { is_floating: true }), window(4, 0, 0, { layout: {} }),
        window(3, 0, 0, { layout: { pos_in_scrolling_layout: ['bad', 1] } }), window(2, 1)];
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [2, 3, 4]);
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
    assert.deepEqual(layout.widths, [80, 160]);
    assert.deepEqual(layout.starts, [0, 84]);
    assert.equal(layout.totalWidth, 244);
    const resized = model.tabGeometry([{ visualWidth: 1200 }, { visualWidth: 1200 }], 4, 36, 1800);
    assert.deepEqual(plain(resized.widths), [160, 160]);
});

test('shrinking a tab only clamps that tab and does not enlarge any other tab', () => {
    const before = model.tabGeometry([{ visualWidth: 1000 }, { visualWidth: 2000 }], 4, 64, 2000);
    const after = model.tabGeometry([{ visualWidth: 100 }, { visualWidth: 2000 }], 4, 64, 2000);
    assert.equal(before.widths[0], 120);
    assert.equal(after.widths[0], 64);
    assert.equal(after.widths[1], before.widths[1]);
    assert.equal(after.widths[1], 240);
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
    assert.deepEqual(plain(mixed.widths), [120, 240, 240]);
    const changed = model.tabGeometry([{ visualWidth: 20 }, { visualWidth: null }], 4, 64, 2000);
    assert.equal(changed.widths[1], mixed.widths[1]);
    const unknown = model.tabGeometry([{ visualWidth: NaN }, { visualWidth: -20 }, {}], 4, 64, 2000);
    assert.deepEqual(plain(unknown.widths), [240, 240, 240]);
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
    assert.equal(model.scrollPosition(layout, 2, 0, 200, true), 488);
    assert.equal(model.scrollPosition(layout, 1, 150, 200, true), 244);
    assert.equal(model.scrollPosition(layout, 1, 244, 200, true), 244);
    assert.equal(model.scrollPosition(layout, -1, -20, 200, true), 0);
    assert.equal(model.scrollPosition(layout, -1, 1000, 200, true), 528);
});

test('manual overflow browsing survives updates until active-window following resumes', () => {
    const windows = [{ visualWidth: 1800 }, { visualWidth: 1800 }, { visualWidth: 1800 }];
    const layout = model.tabGeometry(windows, 4, 64, 1800);
    assert.equal(model.scrollPosition(layout, 0, 300, 200, false), 300);
    const resized = model.tabGeometry([...windows, { visualWidth: 300 }], 4, 64, 1800);
    assert.equal(model.scrollPosition(resized, 0, 300, 200, false), 300);
    assert.equal(model.scrollPosition(resized, 0, 300, 200, true), 0);
    const removed = model.tabGeometry(windows.slice(0, 2), 4, 64, 1800);
    assert.equal(model.scrollPosition(removed, 0, 500, 200, false), 284);
});

test('scrolling handles oversized tabs, short content, and empty workspaces', () => {
    const layout = model.tabGeometry([{ visualWidth: 3600 }, { visualWidth: 1800 }], 4, 64, 1800);
    assert.equal(model.scrollPosition(layout, 0, 100, 200, true), 0);
    assert.equal(model.scrollPosition(layout, 0, 100, 200, false), 100);
    assert.equal(model.scrollPosition(layout, 1, 0, 1000, true), 0);
    assert.equal(model.scrollPosition(layout, 9, 100, 200, true), 100);
    assert.equal(model.scrollPosition({ widths: [], starts: [], totalWidth: 0 }, -1, 100, 200, true), 0);
});


test('floating toggles remove and restore tabs without changing workspace lifetime', () => {
    const input = [window(1, 1), window(2, 2, 1, { is_floating: true })];
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [1]);
    input[0].is_floating = true;
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)), []);
    assert.equal(model.activeWorkspace([workspace], 'DP-1').id, workspace.id);
    input[1].is_floating = false;
    assert.deepEqual(plain(model.workspaceWindows(input, workspace)).map(w => w.id), [2]);
});

test('strip grows without arrows until content exceeds its ceiling', () => {
    assert.deepEqual(plain(model.stripGeometry(0, 640, 40, 4)),
        { width: 40, viewportWidth: 0, showArrows: false });
    assert.deepEqual(plain(model.stripGeometry(200, 640, 40, 4)),
        { width: 244, viewportWidth: 200, showArrows: false });
    assert.deepEqual(plain(model.stripGeometry(596, 640, 40, 4)),
        { width: 640, viewportWidth: 596, showArrows: false });
    assert.deepEqual(plain(model.stripGeometry(597, 640, 40, 4)),
        { width: 640, viewportWidth: 508, showArrows: true });
    assert.equal(model.stripGeometry(2000, 1920, 40, 4).width, 1920);
});


test('host width reductions keep the launcher inside and suppress controls that cannot fit', () => {
    for (const width of [140, 240, 640]) {
        const layout = model.stripGeometry(1000, width, 40, 4);
        const controls = layout.showArrows ? 3 : 1;
        assert.equal(layout.width, width);
        assert.equal(layout.viewportWidth + controls * (40 + 4), width);
    }
    const narrow = model.stripGeometry(1000, 100, 40, 4);
    assert.equal(narrow.showArrows, false);
    assert.equal(narrow.viewportWidth, 56);
    const relaxed = model.stripGeometry(200, 640, 40, 4);
    assert.equal(relaxed.showArrows, false);
});


test('left strip reserves launcher, music, gaps, and actual pill padding', () => {
    const budget = model.barWidthBudget(1920, 'left', 0, 0, 0, 0, [48, 200], 4, 16);
    assert.equal(budget, 1632);
    assert.equal(budget + 32 + 48 + 200 + 8, 1920);
    assert.equal(model.barWidthBudget(1920, 'left', 0, 0, 0, 0, [48], 4, 16), 1836);
});

test('empty center containers do not restrict growth and zero insets leave no artificial gap', () => {
    assert.equal(model.barWidthBudget(1920, 'left', 0, 960, 0, 0, [], 4, 0), 1920);
    assert.equal(model.barWidthBudget(1800, 'left', 0, 900, 0, 0, [], 4, 10), 1780);
});

test('occupied adjacent sections constrain growth on the correct side', () => {
    assert.equal(model.barWidthBudget(1920, 'left', 0, 800, 300, 200, [48], 4, 10), 724);
    assert.equal(model.barWidthBudget(1920, 'right', 200, 800, 300, 0, [48], 4, 10), 744);
    assert.equal(model.barWidthBudget(1920, 'center', 200, 0, 0, 300, [48], 4, 10), 1240);
    assert.equal(model.barWidthBudget(100, 'left', 0, 0, 0, 90, [48], 4, 10), 0);
});


test('wheel navigation uses either axis, normal widget direction, and DMS reverse scrolling', () => {
    const empty = { axis: '', source: '', value: 0 };
    assert.equal(model.wheelNavigation(empty, 0, -120, 0, 0, false).direction, 1);
    assert.equal(model.wheelNavigation(empty, 0, 120, 0, 0, false).direction, -1);
    assert.equal(model.wheelNavigation(empty, -120, 10, 0, 0, false).direction, 1);
    assert.equal(model.wheelNavigation(empty, 0, -120, 0, 0, true).direction, -1);
    assert.equal(model.wheelNavigation(empty, 0, 0, 0, 0, false).direction, 0);
});

test('wheel navigation accumulates smooth input and resets across unit or axis changes', () => {
    const empty = { axis: '', source: '', value: 0 };
    let state = model.wheelNavigation(empty, 0, -60, 0, 0, false);
    assert.equal(state.direction, 0);
    state = model.wheelNavigation(state, 0, -60, 0, 0, false);
    assert.equal(state.direction, 1);
    assert.equal(state.value, 0);
    state = model.wheelNavigation(empty, 0, -60, 0, -20, false);
    assert.equal(state.direction, 0);
    assert.equal(model.wheelNavigation(state, 0, -60, 0, -20, false).direction, 1);
    assert.equal(model.wheelNavigation(state, -60, 0, 0, 0, false).direction, 0);
    state = model.wheelNavigation(empty, 0, 0, 0, -25, false);
    assert.equal(state.direction, 0);
    assert.equal(model.wheelNavigation(state, 0, 0, 0, -25, false).direction, 1);
});


test('widget scroll option defaults to normal and composes with the DMS preference', () => {
    const empty = { axis: '', source: '', value: 0 };
    for (const dmsReverse of [false, true]) {
        for (const deltas of [[0, -120, 0, 0], [-120, 0, 0, 0], [0, -500, 0, -20], [0, 0, 0, -50]]) {
            const current = model.wheelNavigation(empty, ...deltas, dmsReverse);
            const reversed = model.wheelNavigation(empty, ...deltas, dmsReverse, true);
            const normal = model.wheelNavigation(empty, ...deltas, dmsReverse, false);
            assert.equal(normal.direction, current.direction);
            assert.equal(normal.direction, -reversed.direction);
            assert.equal(normal.direction, dmsReverse ? -1 : 1);
        }
    }
});


test('fast and coalesced scrolling preserves every full step and partial remainder', () => {
    const empty = { axis: '', source: '', value: 0 };
    let state = empty;
    let steps = 0;
    for (let event = 0; event < 50; event++) {
        state = model.wheelNavigation(state, 0, -120, 0, 0, false);
        steps += state.steps;
    }
    assert.equal(steps, 50);
    state = model.wheelNavigation(empty, 0, -390, 0, 0, false);
    assert.equal(state.steps, 3);
    assert.equal(state.value, -30);
    state = model.wheelNavigation(state, 0, -90, 0, 0, false);
    assert.equal(state.steps, 1);
    assert.equal(state.value, 0);
    const smooth = model.wheelNavigation(empty, 0, 1200, 0, 100, false);
    assert.equal(smooth.steps, 10);
    assert.equal(smooth.value, 0);
    const pixels = model.wheelNavigation(empty, 0, 0, 0, -125, false);
    assert.equal(pixels.steps, 2);
    assert.equal(pixels.value, -25);
});


test('three rapid wheel notches count three times even when pixel metadata changes', () => {
    let state = { axis: '', source: '', value: 0 };
    let steps = 0;
    for (const pixels of [0, -15, -30]) {
        state = model.wheelNavigation(state, 0, 120, 0, pixels, false);
        steps += state.steps;
        assert.equal(state.steps, 1);
    }
    assert.equal(steps, 3);
    assert.equal(state.value, 0);
    state = model.wheelNavigation({ axis: '', source: '', value: 0 }, 0, 60, 0, 0, false);
    const quiet = model.wheelNavigation(state, 0, 0, 0, 0, false);
    assert.equal(quiet.value, 60);
    state = model.wheelNavigation(quiet, 0, 60, 0, 5, false);
    assert.equal(state.steps, 1);
    assert.equal(state.value, 0);
});

test('incremental tab edits preserve surviving identities through opening, closing, and reordering', () => {
    const sequences = [[1, 2, 3], [1, 3], [1, 4, 3], [3, 1, 4], [4, 5], [], [6]];
    let delegates = [];
    for (const nextIds of sequences) {
        const previous = delegates.slice();
        const previousIds = previous.map(tab => tab.id);
        const edits = plain(model.tabModelChanges(previousIds, nextIds));
        for (const edit of edits) {
            if (edit.type === 'remove') delegates.splice(edit.index, 1);
            else if (edit.type === 'insert') delegates.splice(edit.index, 0, {id: nextIds[edit.index]});
            else delegates.splice(edit.index, 0, delegates.splice(edit.from, 1)[0]);
        }
        assert.deepEqual(delegates.map(tab => tab.id), nextIds);
        assert.deepEqual(previousIds, previous.map(tab => tab.id), 'input remains unchanged');
        for (const survivor of previous.filter(tab => nextIds.includes(tab.id)))
            assert.equal(delegates.find(tab => tab.id === survivor.id), survivor);
        assert.deepEqual(plain(model.tabModelChanges(nextIds, nextIds)), [], 'snapshot-only changes do not recreate tabs');
    }
});


test('configurable tab width scales independently and preserves the readability minimum', () => {
    const windows = [{visualWidth: 960}, {visualWidth: 1920}, {visualWidth: 20}];
    assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920).widths), [120, 240, 96]);
    assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920, 300).widths), [150, 300, 96]);
    assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920, 120).widths), [96, 120, 96]);
    assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920, 480).widths), [240, 480, 96]);
    assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920, 900).widths), [240, 480, 96]);
    assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920, 50).widths), [96, 120, 96]);
    for (const invalid of [NaN, Infinity, 0, -1, null])
        assert.deepEqual(plain(model.tabGeometry(windows, 4, 96, 1920, invalid).widths), [120, 240, 96]);
});

test('drop targets use the dragged rectangle, skip the dragged tab, and handle either end', () => {
    const windows = [{id:1,visualWidth:1920}, {id:2,visualWidth:960}, {id:3,visualWidth:1920}];
    const geometry = model.tabGeometry(windows, 4, 96, 1920);
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 2, -10)),
        {targetId:1, after:false});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 2, 300)),
        {targetId:3, after:false});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 2, 1000)),
        {targetId:3, after:true});
    assert.equal(model.tabDropTarget([{id:1}], {starts:[0],widths:[240]}, 1, 50), null);
    assert.equal(model.tabDropTarget(windows, geometry, 2, NaN), null);
});

test('reordering chooses adjacent stack moves or column swaps and rejects invalid targets', () => {
    const windows = [window(1,1,1),window(2,1,2),window(3,2,1),window(4,3,1)];
    assert.equal(model.reorderStep(windows, workspace, 1, 2, true).action, 'MoveWindowDown');
    assert.equal(model.reorderStep(windows, workspace, 2, 1, false).action, 'MoveWindowUp');
    const cross = model.reorderStep(windows, workspace, 2, 3, true);
    assert.equal(cross.action, 'SwapWindowRight');
    assert.equal(cross.crossColumn, true);
    assert.equal(cross.neighborId, 3);
    assert.deepEqual(plain(cross.expectedIds), [1,3,2,4]);
    assert.equal(model.reorderStep(windows, workspace, 3, 2, false).action, 'SwapWindowLeft');
    assert.equal(model.reorderStep(windows, workspace, 2, 3, false).done, true);
    for (const [sourceId,targetId] of [[1,1],[99,1],[1,99]])
        assert.equal(model.reorderStep(windows, workspace, sourceId, targetId, true), null);
    assert.equal(model.reorderStep(windows, null, 1, 3, true), null);
    assert.equal(model.reorderStep([window(1,1),window(2,3)], workspace, 1, 2, true), null);
    assert.equal(model.reorderStep([window(1,1),window(2,2,1,{is_floating:true})], workspace, 1, 2, true), null);
    assert.equal(model.reorderStep([window(1,1),window(2,2,1,{layout:{}})], workspace, 1, 2, true), null);
});

test('reactive adjacent steps reach every insertion order across mixed stacks without moving other workspaces', () => {
    const original = [window(1,1,1),window(2,1,2),window(3,2,1),window(4,3,1),window(5,3,2)];
    for (const source of original) for (const target of original) for (const after of [false,true]) {
        if (source.id === target.id) continue;
        const input = structuredClone(original);
        const untouched = window(90,1,1,{workspace_id:20});
        input.push(untouched);
        const expected = original.map(w => w.id).filter(id => id !== source.id);
        expected.splice(expected.indexOf(target.id) + (after ? 1 : 0), 0, source.id);
        let complete = false;
        for (let count=0; count < original.length; count++) {
            const step = model.reorderStep(input, workspace, source.id, target.id, after);
            assert.ok(step);
            if (step.done) { complete=true; break; }
            const a = input.find(w => w.id === source.id);
            const b = input.find(w => w.id === step.neighborId);
            const pos = a.layout.pos_in_scrolling_layout;
            a.layout.pos_in_scrolling_layout = b.layout.pos_in_scrolling_layout;
            b.layout.pos_in_scrolling_layout = pos;
            assert.deepEqual(plain(model.workspaceWindows(input,workspace)).map(w=>w.id), plain(step.expectedIds));
        }
        assert.ok(complete);
        assert.deepEqual(plain(model.workspaceWindows(input,workspace)).map(w=>w.id), expected);
        assert.equal(input.find(w=>w.id===90), untouched);
    }
});

test('drag preview opens the insertion gap using individual widths and leaves unrelated tabs in place', () => {
    const windows = [{id:1,visualWidth:1920}, {id:2,visualWidth:960}, {id:3,visualWidth:2880}, {id:4,visualWidth:1920}];
    const geometry = model.tabGeometry(windows, 4, 96, 1920);
    assert.deepEqual(plain(model.tabDragOffsets(windows, geometry, 1, {targetId:3,after:true}, 4)),
        [488,-244,-244,0]);
    assert.deepEqual(plain(model.tabDragOffsets(windows, geometry, 3, {targetId:1,after:false}, 4)),
        [364,364,-368,0]);
    assert.deepEqual(plain(model.tabDragOffsets(windows, geometry, 2, {targetId:3,after:false}, 4)),
        [0,0,0,0]);
    for (const [source,target] of [[null,null],[99,{targetId:3,after:true}],[1,{targetId:99,after:false}]])
        assert.deepEqual(plain(model.tabDragOffsets(windows, geometry, source, target, 4)), [0,0,0,0]);
    assert.deepEqual(plain(model.tabDragOffsets([], {starts:[],widths:[]}, 1, null, 4)), []);
    assert.deepEqual(windows.map(w=>w.id), [1,2,3,4], 'preview does not change compositor order');
});


test('neighbors move aside at 50% overlap of the leading edge in either direction', () => {
    const windows = [{id:1,visualWidth:1920}, {id:2,visualWidth:960}, {id:3,visualWidth:1920}];
    const geometry = model.tabGeometry(windows, 4, 96, 1920);
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 1, 0)), {targetId:2,after:false});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 1, 63)), {targetId:2,after:false});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 1, 64)), {targetId:2,after:true});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 3, 368)), {targetId:2,after:true});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 3, 305)), {targetId:2,after:true});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 3, 304)), {targetId:2,after:false});
    assert.deepEqual(plain(model.tabDropTarget(windows, geometry, 1, 63)), {targetId:2,after:false}, 'returning across threshold restores slot');
    assert.equal(model.tabDropTarget(windows, geometry, 99, 100), null);
});
