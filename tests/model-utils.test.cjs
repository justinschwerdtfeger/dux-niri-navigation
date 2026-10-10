const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadModel, plain } = require('./helpers.cjs');
const model = loadModel('ModelUtils.js');

test('unchanged rows produce no writes and changed roles preserve object identity', () => {
    const rows = [
        { id: 1, title: 'One', active: true },
        { id: 2, title: 'Two', active: false },
    ];
    const original = rows.slice();
    const writes = [];
    const list = {
        get count() {
            return rows.length;
        },
        get: (index) => rows[index],
        insert: (index, row) => rows.splice(index, 0, { ...row }),
        remove: (index) => rows.splice(index, 1),
        move: (from, to) => rows.splice(to, 0, rows.splice(from, 1)[0]),
        setProperty: (index, role, value) => {
            writes.push([index, role, value]);
            rows[index][role] = value;
        },
    };
    assert.equal(
        model.syncRows(
            list,
            rows.map((row) => ({ ...row })),
            'id',
        ),
        false,
    );
    assert.deepEqual(writes, []);
    assert.equal(model.syncRows(list, [{ ...rows[1], title: 'Updated' }, rows[0]], 'id'), true);
    assert.equal(rows[0], original[1]);
    assert.equal(rows[1], original[0]);
    assert.deepEqual(writes, [[0, 'title', 'Updated']]);
});

test('all small list insertions, removals, and permutations preserve survivors', () => {
    const permutations = (values) =>
        values.length
            ? values.flatMap((value, index) =>
                  permutations(values.filter((_, i) => i !== index)).map((rest) => [
                      value,
                      ...rest,
                  ]),
              )
            : [[]];
    const sequences = [[]];
    for (let mask = 1; mask < 16; mask++)
        sequences.push(...permutations([1, 2, 3, 4].filter((id) => mask & (1 << (id - 1)))));
    for (const before of sequences) {
        for (const after of sequences) {
            const delegates = before.map((id) => ({ id }));
            const survivors = delegates.filter((row) => after.includes(row.id));
            for (const edit of model.modelChanges(before, after)) {
                if (edit.type === 'remove') delegates.splice(edit.index, 1);
                else if (edit.type === 'insert')
                    delegates.splice(edit.index, 0, { id: after[edit.index] });
                else delegates.splice(edit.index, 0, delegates.splice(edit.from, 1)[0]);
            }
            assert.deepEqual(
                delegates.map((row) => row.id),
                after,
            );
            for (const row of survivors)
                assert.equal(
                    delegates.find((next) => next.id === row.id),
                    row,
                );
        }
    }
});

test('incremental tab edits preserve surviving identities through opening, closing, and reordering', () => {
    const sequences = [[1, 2, 3], [1, 3], [1, 4, 3], [3, 1, 4], [4, 5], [], [6]];
    let delegates = [];
    for (const nextIds of sequences) {
        const previous = delegates.slice();
        const previousIds = previous.map((tab) => tab.id);
        const edits = plain(model.modelChanges(previousIds, nextIds));
        for (const edit of edits) {
            if (edit.type === 'remove') delegates.splice(edit.index, 1);
            else if (edit.type === 'insert')
                delegates.splice(edit.index, 0, { id: nextIds[edit.index] });
            else delegates.splice(edit.index, 0, delegates.splice(edit.from, 1)[0]);
        }
        assert.deepEqual(
            delegates.map((tab) => tab.id),
            nextIds,
        );
        assert.deepEqual(
            previousIds,
            previous.map((tab) => tab.id),
            'input remains unchanged',
        );
        for (const survivor of previous.filter((tab) => nextIds.includes(tab.id)))
            assert.equal(
                delegates.find((tab) => tab.id === survivor.id),
                survivor,
            );
        assert.deepEqual(
            plain(model.modelChanges(nextIds, nextIds)),
            [],
            'snapshot-only changes do not recreate tabs',
        );
    }
});
