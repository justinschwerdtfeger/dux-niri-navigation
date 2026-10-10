const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadModel, plain } = require('./helpers.cjs');
const model = loadModel('ReorderModel.js');
const workspace = { id: 10 };
const window = (id, column, row = 1) => ({
    id,
    workspace_id: 10,
    layout: { pos_in_scrolling_layout: [column, row] },
});
const focus = (windows, id) =>
    windows.map((window) => ({ ...window, is_focused: window.id === id }));

test('cross-column moves await neighbor focus, source focus, and layout before advancing', () => {
    let windows = [window(1, 1), window(2, 2), window(3, 3)];
    let pending = model.start(windows, workspace, 1, 3, true);
    const initial = plain(pending);
    let result = model.advance(pending, windows, workspace);
    assert.deepEqual(plain(result.request), { focusId: 2 });
    assert.deepEqual(plain(pending), initial, 'input state remains immutable');
    pending = result.pending;
    assert.equal(
        model.advance(pending, windows, workspace).request,
        null,
        'no unacknowledged swap',
    );
    windows = focus(windows, 2);
    result = model.advance(pending, windows, workspace);
    assert.deepEqual(plain(result.request), { focusId: 1 });
    pending = result.pending;
    assert.equal(model.advance(pending, windows, workspace).request, null);
    windows = focus(windows, 1);
    result = model.advance(pending, windows, workspace);
    assert.deepEqual(plain(result.request), { action: 'SwapWindowRight' });
    pending = result.pending;
    for (let i = 0; i < 3; i++) {
        result = model.advance(pending, windows, workspace);
        assert.equal(result.request, null, 'unchanged snapshots must not repeat an action');
    }
    windows = focus([window(2, 1), window(1, 2), window(3, 3)], 1);
    result = model.advance(pending, windows, workspace);
    assert.deepEqual(plain(result.request), { focusId: 3 });
    result = model.advance(result.pending, focus(windows, 3), workspace);
    result = model.advance(result.pending, focus(windows, 1), workspace);
    assert.deepEqual(plain(result.request), { action: 'SwapWindowRight' });
    windows = focus([window(2, 1), window(3, 2), window(1, 3)], 1);
    assert.equal(model.advance(result.pending, windows, workspace).pending, null);
});

test('stack moves require source focus only and finish on the expected layout', () => {
    const windows = [window(1, 1, 1), window(2, 1, 2)];
    let result = model.advance(model.start(windows, workspace, 2, 1, false), windows, workspace);
    assert.deepEqual(plain(result.request), { focusId: 2 });
    result = model.advance(result.pending, focus(windows, 2), workspace);
    assert.deepEqual(plain(result.request), { action: 'MoveWindowUp' });
    assert.equal(
        model.advance(result.pending, focus([window(2, 1, 1), window(1, 1, 2)], 2), workspace)
            .pending,
        null,
    );
});

test('invalid targets, missing windows, workspace changes, and unexpected layouts cancel', () => {
    const windows = [window(1, 1), window(2, 2), window(3, 3)];
    for (const [source, target, after] of [
        [1, 99, true],
        [1, 1, true],
        [1, 2, false],
    ])
        assert.equal(model.start(windows, workspace, source, target, after), null);
    const result = model.advance(model.start(windows, workspace, 1, 3, true), windows, workspace);
    for (const [snapshot, ws] of [
        [windows.slice(1), workspace],
        [windows, null],
        [windows, { id: 20 }],
        [[window(3, 1), window(2, 2), window(1, 3)], workspace],
        [[window(1, 1), window(2, 3), window(3, 4)], workspace],
    ]) {
        assert.equal(model.advance(result.pending, snapshot, ws).pending, null);
    }
});

test('external focus during an unacknowledged layout cancels instead of repeating a swap', () => {
    const windows = [window(1, 1), window(2, 1, 2), window(3, 2)];
    let result = model.advance(model.start(windows, workspace, 1, 2, true), windows, workspace);
    result = model.advance(result.pending, focus(windows, 1), workspace);
    assert.equal(model.advance(result.pending, focus(windows, 3), workspace).pending, null);
});
