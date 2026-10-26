const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadModel, plain } = require('./helpers.cjs');
const model = loadModel('WorkspaceModel.js');
const workspaces = [
    { id: 12, idx: 2, output: 'DP-1' },
    { id: 22, idx: 1, output: 'DP-2' },
    { id: 11, idx: 1, output: 'DP-1', is_active: true },
    { id: 13, idx: 3, output: 'DP-1' },
];

test('unchanged snapshots and repeated selections keep shared assignment identity', () => {
    const state = model.reconcile({}, workspaces, [{ id: 9, workspace_id: 11, app_id: 'kitty' }]);
    assert.equal(model.reconcile(state, workspaces.slice().reverse(), []), state);
    assert.equal(model.setIcon(state, 11, null), state);
    const changed = model.setIcon(state, 11, 'web');
    assert.equal(model.setIcon(changed, 11, 'web'), changed);
    const replaced = model.reconcile(
        state,
        workspaces.map((ws) => (ws.id === 13 ? { ...ws, id: 14 } : ws)),
        [],
    );
    assert.notEqual(replaced, state);
    assert.equal(Object.hasOwn(replaced, '13'), false);
    assert.equal(model.iconFor(replaced, 14), 'add');
});

test('rail scopes and orders workspaces, retaining active and trailing empty workspaces', () => {
    const before = JSON.stringify(workspaces);
    assert.deepEqual(
        plain(model.outputWorkspaces(workspaces, 'DP-1')).map((ws) => ws.id),
        [11, 12, 13],
    );
    assert.deepEqual(
        plain(model.outputWorkspaces(workspaces, 'DP-2')).map((ws) => ws.id),
        [22],
    );
    assert.deepEqual(plain(model.outputWorkspaces(workspaces, '')), []);
    assert.deepEqual(plain(model.outputWorkspaces(workspaces, 'missing')), []);
    assert.equal(JSON.stringify(workspaces), before);
    assert.equal(model.canFocus(workspaces, 'DP-1', 11), true);
    for (const id of [22, 99, null, undefined])
        assert.equal(model.canFocus(workspaces, 'DP-1', id), false);
});

test('first observed window seeds a monochrome category; later windows and closure keep it stable', () => {
    let state = model.reconcile({}, workspaces, []);
    assert.equal(model.iconFor(state, 11), 'add');
    const windows = [
        { id: 9, workspace_id: 11, app_id: 'kitty' },
        { id: 5, workspace_id: 11, app_id: 'org.mozilla.firefox' },
        { id: 10, workspace_id: 22, app_id: 'helium', is_floating: true },
    ];
    state = model.reconcile(state, workspaces, windows);
    assert.equal(model.iconFor(state, 11), 'web');
    assert.equal(model.iconFor(state, 22), 'web');
    state = model.reconcile(state, workspaces, [{ id: 3, workspace_id: 11, app_id: 'code' }]);
    assert.equal(model.iconFor(state, 11), 'web');
    state = model.reconcile(state, workspaces, []);
    assert.equal(model.iconFor(state, 11), 'web');
    assert.equal(model.iconFor(state, 13), 'add');
});

test('custom icons follow IDs through renumbering and output movement, then disappear with workspace', () => {
    let state = model.reconcile({}, workspaces, [{ id: 1, workspace_id: 11, app_id: 'firefox' }]);
    state = model.setIcon(state, 11, 'science');
    const changed = workspaces.map((ws) => ({ ...ws, idx: ws.idx + 1, output: 'DP-2' }));
    state = model.reconcile(state, changed, []);
    assert.equal(model.iconFor(state, 11), 'science');
    state = model.setIcon(state, 11, null);
    assert.equal(model.iconFor(state, 11), 'web');
    state = model.setIcon(state, 11, 'star');
    state = model.reconcile(
        state,
        changed.filter((ws) => ws.id !== 11),
        [],
    );
    assert.equal(Object.hasOwn(state, '11'), false);
    assert.strictEqual(model.setIcon(state, 11, 'star'), state);
    state = model.reconcile(state, workspaces, []);
    assert.equal(model.iconFor(state, 11), 'add');
    assert.deepEqual(plain(model.reconcile(state, [], [])), {});
});

test('manual choices on empty workspaces survive seeding and stale or invalid edits are rejected', () => {
    let state = model.reconcile({}, workspaces, []);
    state = model.setIcon(state, 13, 'school');
    state = model.reconcile(state, workspaces, [{ id: 2, workspace_id: 13, app_id: 'helium' }]);
    assert.equal(model.iconFor(state, 13), 'school');
    const before = JSON.stringify(state);
    assert.strictEqual(model.setIcon(state, 13, 'invalid-icon'), state);
    assert.strictEqual(model.setIcon(state, null, 'web'), state);
    const reset = model.setIcon(state, 13, null);
    assert.equal(model.iconFor(reset, 13), 'web');
    assert.equal(JSON.stringify(state), before);
});

test('pins preserve user order, deduplicate and sanitize saved settings independently of workspaces', () => {
    assert.deepEqual(plain(model.pinnedIcons(['web', 'bad', 'web', 'code'])), ['web', 'code']);
    for (const input of [null, {}, 'web', 4]) assert.deepEqual(plain(model.pinnedIcons(input)), []);
    let pins = model.togglePin([], 'web');
    pins = model.togglePin(pins, 'code');
    assert.deepEqual(plain(pins), ['web', 'code']);
    assert.deepEqual(plain(model.togglePin(pins, 'web')), ['code']);
    assert.deepEqual(plain(model.togglePin(pins, 'invalid')), ['web', 'code']);
    model.reconcile({}, [], []);
    assert.deepEqual(plain(pins), ['web', 'code']);
    for (const app of ['firefox', 'org.mozilla.firefox', 'Helium', 'com.helium.browser'])
        assert.equal(model.appIcon(app), 'web');
    assert.equal(model.appIcon('unknown'), 'desktop_windows');
});
