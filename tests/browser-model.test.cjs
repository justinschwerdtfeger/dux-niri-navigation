const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../BrowserModel.js'), 'utf8')
    .replace(/^\.pragma library\s*\n/, ''), model);
const match = (windows, tabs) => JSON.parse(JSON.stringify(model.faviconSources(windows, tabs)));
const window = (id, title, changes = {}) => ({ id, title: `${title} - Helium`, app_id: 'helium', ...changes });
const tab = (title, changes = {}) => ({ browser: 'Helium', title,
    windowId: 987, instance: 'Helium', iconSource: 'https://example.com/favicon.png', ...changes });

test('maps each unique active title to its Niri ID regardless of ordering or focus', () => {
    assert.deepEqual(match([window(2, 'Two'), window(1, 'One')], [tab('One'), tab('Two')]),
        { 1: 'https://example.com/favicon.png', 2: 'https://example.com/favicon.png' });
});

test('duplicate compositor titles share an agreed icon across outputs and floating windows', () => {
    assert.deepEqual(match([window(1, 'Same', { workspace_id: 1 }),
        window(2, 'Same', { workspace_id: 20, is_focused: true, is_floating: true })],
        [tab('Same'), tab('Same', { windowId: 5 })]),
        { 1: 'https://example.com/favicon.png', 2: 'https://example.com/favicon.png' });
});

test('duplicate active tab titles across profiles can share identical artwork', () => {
    assert.deepEqual(match([window(1, 'Same')], [tab('Same'),
        tab('Same', { instance: 'Helium2', windowId: 5 })]),
        { 1: 'https://example.com/favicon.png' });
});

test('duplicate titles with conflicting or missing icons fall back for every window', () => {
    const windows = [window(1, 'Same'), window(2, 'Same', { workspace_id: 20 })];
    for (const iconSource of ['https://example.com/other.png', '', null, undefined]) {
        const tabs = [tab('Same'), tab('Same', { instance: 'Helium2', iconSource })];
        assert.deepEqual(match(windows, tabs), {});
        assert.deepEqual(match(windows.slice().reverse(), tabs.slice().reverse()), {});
    }
});

test('shared icons react to disagreement, recovery, and candidate removal without saved identity', () => {
    const windows = [window(1, 'Same'), window(2, 'Same')];
    const agreed = { 1: 'https://example.com/favicon.png', 2: 'https://example.com/favicon.png' };
    assert.deepEqual(match(windows, [tab('Same'), tab('Same')]), agreed);
    assert.deepEqual(match(windows, [tab('Same'), tab('Same', { iconSource: '' })]), {});
    assert.deepEqual(match(windows, [tab('Same')]), agreed);
    assert.deepEqual(match(windows, []), {});
    assert.deepEqual(match(windows, [tab('Same'), tab('Same')]), agreed);
});

test('does not match other apps, empty titles, substring titles, or another browser', () => {
    assert.deepEqual(match([window(1, 'One', { app_id: 'firefox' }), window(2, ''),
        window(3, 'One more'), window(4, 'Other')], [tab('One'), tab(''),
        tab('Other', { browser: 'Chrome' })]), {});
});

test('title navigation, tab disconnect, and window removal immediately clear old associations', () => {
    const windows = [window(1, 'Old')];
    assert.equal(match(windows, [tab('Old')])[1], 'https://example.com/favicon.png');
    assert.deepEqual(match([window(1, 'New')], [tab('Old')]), {});
    assert.equal(match([window(1, 'New')], [tab('New', { iconSource: 'file:///tmp/icon.png' })])[1], 'file:///tmp/icon.png');
    assert.deepEqual(match(windows, []), {});
    assert.deepEqual(match([], [tab('Old')]), {});
});

test('missing icons fall back and title normalization removes only the final suffix', () => {
    assert.deepEqual(match([window(1, 'One - Helium')], [tab('One - Helium', { iconSource: '' })]), {});
    assert.deepEqual(match([window(1, 'One - Helium')], [tab('One - Helium')]),
        { 1: 'https://example.com/favicon.png' });
    assert.deepEqual(match([window(1, 'One')], [tab('One', { iconSource: null })]), {});
    assert.deepEqual(match(null, null), {});
});
