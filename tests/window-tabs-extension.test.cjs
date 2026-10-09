const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function event() {
    const listeners = [];
    return {
        addListener: listener => listeners.push(listener),
        emit: (...args) => listeners.forEach(listener => listener(...args))
    };
}

async function browser({ enabled = true, type = 'normal', focused = true, incognito = false } = {}) {
    const { registerWindowTabs } = await import('../extensions/window-tabs/controller.mjs');
    const tabs = new Map([[1, { id: 1, windowId: 10, active: true }]]);
    const windows = new Map([[10, { id: 10, type, focused, incognito }]]);
    const saved = { enabled };
    const moves = [];
    const errors = [];
    const badge = {};
    let failure = null;
    const api = {
        storage: { onChanged: event(), local: {
            get: async defaults => ({ ...defaults, ...saved }),
            set: async values => Object.assign(saved, values)
        } },
        tabs: {
            onCreated: event(),
            get: async id => {
                if (!tabs.has(id)) throw new Error(`No tab with id: ${id}`);
                return { ...tabs.get(id) };
            },
            query: async ({ windowId }) => [...tabs.values()]
                .filter(tab => tab.windowId === windowId).map(tab => ({ ...tab }))
        },
        windows: {
            get: async id => {
                if (!windows.has(id)) throw new Error(`No window with id: ${id}`);
                return { ...windows.get(id) };
            },
            create: async options => {
                if (failure) {
                    const error = failure;
                    failure = null;
                    throw error;
                }
                const tab = tabs.get(options.tabId);
                assert.ok(tab, 'moves an existing tab');
                assert.ok([...tabs.values()].some(other => other.id !== tab.id
                    && other.windowId === tab.windowId), 'leaves a source tab');
                moves.push(options);
                const id = 20 + moves.length;
                windows.set(id, { id, type: options.type, focused: options.focused,
                    incognito: options.incognito });
                tab.windowId = id;
                tab.active = true;
                return { ...windows.get(id) };
            }
        },
        action: {
            onClicked: event(),
            setBadgeText: async ({ text }) => { badge.text = text; },
            setBadgeBackgroundColor: async ({ color }) => { badge.color = color; },
            setTitle: async ({ title }) => { badge.title = title; }
        },
        runtime: { onInstalled: event(), onStartup: event() }
    };
    const controller = registerWindowTabs(api, (...args) => errors.push(args));
    await controller.whenIdle();
    function add(id, changes = {}) {
        const tab = { id, windowId: 10, active: false, ...changes };
        if (tab.active) {
            for (const other of tabs.values()) {
                if (other.windowId === tab.windowId) other.active = false;
            }
        }
        tabs.set(id, tab);
        api.tabs.onCreated.emit({ ...tab });
        return tab;
    }
    return { api, tabs, windows, moves, badge, saved, errors, add,
        idle: controller.whenIdle, fail: error => { failure = error; } };
}

test('packages a loadable MV3 module worker with only storage permission', () => {
    const root = path.join(__dirname, '../extensions/window-tabs');
    const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json')));
    assert.equal(manifest.manifest_version, 3);
    assert.equal(manifest.background.type, 'module');
    assert.ok(fs.statSync(path.join(root, manifest.background.service_worker)).isFile());
    assert.deepEqual(manifest.permissions, ['storage']);
    assert.equal(manifest.host_permissions, undefined);
    assert.equal(manifest.incognito, 'split');
});

test('moves a background tab by identity without requesting focus or reopening its URL', async () => {
    const b = await browser();
    const tab = b.add(2, { pageState: 'unsaved form' });
    await b.idle();
    assert.deepEqual(b.moves, [{ tabId: 2, type: 'normal', incognito: false, focused: false }]);
    assert.equal(tab.pageState, 'unsaved form');
    assert.equal(b.tabs.get(1).windowId, 10);
});

test('an active new tab in a focused normal window requests foreground focus', async () => {
    const b = await browser();
    b.add(2, { active: true });
    await b.idle();
    assert.equal(b.moves[0].focused, true);
});

test('an unfocused source or a tab that lost activation does not request focus', async () => {
    for (const focused of [false, true]) {
        const b = await browser({ focused });
        const tab = b.add(2, { active: true });
        if (focused) tab.active = false;
        await b.idle();
        assert.equal(b.moves[0].focused, false);
    }
});

test('leaves the only tab in a newly created window alone', async () => {
    const b = await browser();
    b.windows.set(11, { id: 11, type: 'normal', incognito: false, focused: true });
    b.add(2, { windowId: 11, active: true });
    await b.idle();
    assert.equal(b.moves.length, 0);
});

test('excludes popup, app, and devtools windows', async () => {
    for (const type of ['popup', 'app', 'devtools']) {
        const b = await browser({ type });
        b.add(2);
        await b.idle();
        assert.equal(b.moves.length, 0);
    }
});

test('serializes a burst of new tabs without emptying the source', async () => {
    const b = await browser();
    for (let id = 2; id <= 12; id++) b.add(id);
    await b.idle();
    assert.equal(b.moves.length, 11);
    assert.equal(new Set([...b.tabs.values()].map(tab => tab.windowId)).size, 12);
    assert.equal(b.tabs.get(1).windowId, 10);
});

test('preserves private status for detached incognito tabs', async () => {
    const b = await browser({ incognito: true });
    b.add(2);
    await b.idle();
    assert.equal(b.moves[0].incognito, true);
});

test('pause/resume persists and does not sweep existing tabs', async () => {
    const b = await browser();
    assert.equal(b.badge.text, 'ON');
    b.api.action.onClicked.emit();
    await b.idle();
    assert.equal(b.saved.enabled, false);
    assert.equal(b.badge.text, 'OFF');
    b.add(2);
    await b.idle();
    assert.equal(b.moves.length, 0);
    b.api.action.onClicked.emit();
    await b.idle();
    assert.equal(b.saved.enabled, true);
    assert.equal(b.badge.text, 'ON');
    assert.equal(b.moves.length, 0);
    b.add(3);
    await b.idle();
    assert.equal(b.moves[0].tabId, 3);
    const restarted = await browser({ enabled: false });
    restarted.api.runtime.onStartup.emit();
    restarted.add(2);
    await restarted.idle();
    assert.equal(restarted.badge.text, 'OFF');
    assert.equal(restarted.moves.length, 0);
});

test('ignores tabs closed or manually moved while queued', async () => {
    const b = await browser();
    b.add(2);
    b.tabs.delete(2);
    b.add(3).windowId = 99;
    await b.idle();
    assert.equal(b.moves.length, 0);
    assert.equal(b.errors.length, 0);
});

test('API move failure preserves tabs, reports it, and allows later events', async () => {
    const b = await browser();
    b.fail(new Error('Tabs cannot be edited right now (user may be dragging a tab).'));
    b.add(2);
    await b.idle();
    assert.equal(b.tabs.get(2).windowId, 10);
    assert.equal(b.badge.text, '!');
    assert.equal(b.errors.length, 1);
    b.add(3);
    await b.idle();
    assert.equal(b.moves[0].tabId, 3);
    assert.equal(b.tabs.get(2).windowId, 10);
});

test('unexpected query failures are reported rather than silently skipped', async () => {
    const b = await browser();
    b.api.tabs.query = async () => { throw new Error('Unexpected browser failure'); };
    b.add(2);
    await b.idle();
    assert.equal(b.errors.length, 1);
    assert.equal(b.moves.length, 0);
});

test('a shared preference change refreshes the badge and pauses new moves', async () => {
    const b = await browser();
    b.saved.enabled = false;
    b.api.storage.onChanged.emit({ enabled: { oldValue: true, newValue: false } }, 'local');
    b.add(2);
    await b.idle();
    assert.equal(b.badge.text, 'OFF');
    assert.equal(b.moves.length, 0);
});

test('does not request focus if the source loses focus during browser queries', async () => {
    const b = await browser();
    const originalQuery = b.api.tabs.query;
    b.api.tabs.query = async query => {
        b.windows.get(10).focused = false;
        return originalQuery(query);
    };
    b.add(2, { active: true });
    await b.idle();
    assert.equal(b.moves[0].focused, false);
});
