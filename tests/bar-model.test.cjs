const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadModel } = require('./helpers.cjs');
const model = loadModel('BarModel.js');
const budget = (changes = {}) =>
    model.primaryBudget({
        length: 1920,
        section: 'left',
        leading: 0,
        centerStart: 0,
        center: 0,
        trailing: 0,
        siblings: [],
        gap: 4,
        padding: 0,
        ...changes,
    });

test('reserves siblings, gaps, and actual pill padding once', () => {
    const available = budget({ siblings: [48, 200], padding: 16 });
    assert.equal(available, 1632);
    assert.equal(available + 32 + 48 + 200 + 8, 1920);
    assert.equal(budget({ siblings: [48], padding: 16 }), 1836);
});

test('empty center containers and zero insets do not restrict growth', () => {
    assert.equal(budget({ centerStart: 960 }), 1920);
    assert.equal(budget({ length: 1800, centerStart: 900, padding: 10 }), 1780);
});

test('occupied neighboring sections constrain the correct side', () => {
    const shared = { centerStart: 800, center: 300, siblings: [48], padding: 10 };
    assert.equal(budget({ ...shared, trailing: 200 }), 724);
    assert.equal(budget({ ...shared, section: 'right', leading: 200 }), 744);
    assert.equal(
        budget({ section: 'center', leading: 200, trailing: 300, siblings: [48], padding: 10 }),
        1240,
    );
    assert.equal(budget({ length: 100, trailing: 90, siblings: [48], padding: 10 }), 0);
});
