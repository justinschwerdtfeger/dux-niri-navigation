.pragma library
// ID-keyed reconciliation shared by both navigation views. Keep surviving
// delegates and avoid role notifications for unchanged snapshots.
function modelChanges(previousIds, nextIds) {
    const ids = previousIds.slice();
    const next = new Set(nextIds);
    const edits = [];
    for (let index = ids.length - 1; index >= 0; index--) {
        if (!next.has(ids[index])) {
            edits.push({ type: 'remove', index: index });
            ids.splice(index, 1);
        }
    }
    nextIds.forEach((id, index) => {
        // Most snapshots preserve order. Avoid a search for that common case.
        if (ids[index] === id) return;
        const from = ids.indexOf(id, index);
        if (from < 0) {
            edits.push({ type: 'insert', index: index });
            ids.splice(index, 0, id);
        } else {
            edits.push({ type: 'move', from: from, index: index });
            ids.splice(index, 0, ids.splice(from, 1)[0]);
        }
    });
    return edits;
}

function syncRows(model, rows, identityRole) {
    const previousIds = [];
    for (let index = 0; index < model.count; index++)
        previousIds.push(model.get(index)[identityRole]);
    const edits = modelChanges(
        previousIds,
        rows.map((row) => row[identityRole]),
    );
    for (const edit of edits) {
        if (edit.type === 'remove') model.remove(edit.index);
        else if (edit.type === 'insert') model.insert(edit.index, rows[edit.index]);
        else model.move(edit.from, edit.index, 1);
    }
    rows.forEach((row, index) => {
        const previous = model.get(index);
        for (const role of Object.keys(row)) {
            if (previous[role] !== row[role]) model.setProperty(index, role, row[role]);
        }
    });
    return edits.length > 0;
}
