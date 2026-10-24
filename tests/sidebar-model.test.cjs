const assert = require('node:assert/strict');
const test = require('node:test');
const { loadModel, plain } = require('./helpers.cjs');
const model = loadModel('SidebarModel.js');

test('sidebars default off and sanitize persisted display options', () => {
    assert.deepEqual(plain(model.configuration({}, 1920)), {
        mode: 'off',
        side: 'left',
        width: 240,
        compactWidth: 48,
        trigger: 'click',
        pushWindows: false,
    });
    const invalid = model.configuration(
        {
            sidebarMode: 'bad',
            sidebarWidth: 'bad',
            sidebarSide: 'top',
            sidebarTrigger: 'bad',
            sidebarPushWindows: 'true',
        },
        1920,
    );
    assert.deepEqual(plain(invalid), plain(model.configuration({}, 1920)));
});

test('title width respects explicit bounds and small monitor geometry', () => {
    assert.equal(model.configuration({ sidebarWidth: 900 }, 1920).width, 480);
    assert.equal(model.configuration({ sidebarWidth: 20 }, 1920).width, 160);
    assert.equal(model.configuration({ sidebarWidth: 480 }, 600).width, 300);
    assert.equal(model.configuration({ sidebarWidth: 240 }, 200).width, 100);
});

test('pinned titles reserve full width; expandable rails can overlay or push windows', () => {
    const config = model.configuration({ sidebarMode: 'expandable' }, 1920);
    assert.deepEqual(plain(model.geometry(config, false)), {
        showTitles: false,
        width: 48,
        surfaceWidth: 240,
        reservedWidth: 48,
    });
    assert.deepEqual(plain(model.geometry(config, true)), {
        showTitles: true,
        width: 240,
        surfaceWidth: 240,
        reservedWidth: 48,
    });
    config.pushWindows = true;
    assert.equal(model.geometry(config, true).reservedWidth, 240);
    assert.equal(model.geometry(config, false).reservedWidth, 48);
    config.mode = 'pinned';
    config.pushWindows = false;
    assert.deepEqual(plain(model.geometry(config, false)), {
        showTitles: true,
        width: 240,
        surfaceWidth: 240,
        reservedWidth: 240,
    });
    config.mode = 'off';
    assert.equal(model.geometry(config, true).reservedWidth, 0);
});

test('monitor selection follows live screen membership without a fallback', () => {
    const screens = [{ name: 'DP-1' }, { name: 'eDP-1' }];
    assert.equal(model.outputs(screens, {}).length, 0);
    assert.equal(model.outputs(screens, { sidebarMode: 'expandable' }).length, 2);
    const data = { sidebarMode: 'pinned', sidebarOutput: 'DP-1' };
    assert.equal(model.outputs(screens, data)[0], screens[0]);
    assert.equal(model.outputs(screens.slice(1), data).length, 0);
    assert.equal(model.outputs(screens, { ...data, sidebarOutput: 'missing' }).length, 0);
});

test('animation preserves native surface width and only target changes reserve space', () => {
    const config = model.configuration({ sidebarMode: 'expandable' }, 1920);
    for (const expanded of [false, true]) {
        for (const width of [48, 60, 120.5, 200, 240]) {
            assert.equal(model.geometry(config, expanded, width).width, width);
            assert.equal(model.geometry(config, expanded, width).surfaceWidth, 240);
            assert.equal(model.geometry(config, expanded, width).reservedWidth, 48);
            config.pushWindows = true;
            assert.equal(
                model.geometry(config, expanded, width).reservedWidth,
                expanded ? 240 : 48,
            );
            config.pushWindows = false;
        }
    }
    assert.equal(model.geometry(config, true, 999).width, 240);
    assert.equal(model.geometry(config, false, 0).width, 48);
    assert.equal(model.geometry(config, true, NaN).width, 240);
});
