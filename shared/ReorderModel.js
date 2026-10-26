.pragma library
.import "WindowModel.js" as Windows
// Pure acknowledgment state machine. The QML adapter owns IPC and the timeout.
function start(windows, workspace, sourceId, targetId, after) {
    const step = Windows.reorderStep(windows, workspace, sourceId, targetId, after);
    return !step || step.done
        ? null
        : {
              sourceId: sourceId,
              targetId: targetId,
              after: after,
              workspaceId: workspace.id,
              stage: 'next',
              step: null,
          };
}

function advance(pending, windows, workspace) {
    const stopped = { pending: null, request: null };
    if (!pending || !workspace || workspace.id !== pending.workspaceId) return stopped;
    const ids = Windows.orderedWindows(windows, workspace).map((window) => window.id);
    if (!ids.includes(pending.sourceId) || !ids.includes(pending.targetId)) return stopped;
    const sameIds = (other) =>
        ids.length === other.length && ids.every((id, index) => id === other[index]);
    const focusedId = windows.find((window) => window.is_focused)?.id ?? null;
    const next = Object.assign({}, pending);
    const waiting = { pending: next, request: null };
    const focus = (id, stage) => {
        next.stage = stage;
        return { pending: next, request: { focusId: id } };
    };
    if (next.stage === 'layout') {
        if (sameIds(next.step.expectedIds)) {
            next.stage = 'next';
        } else {
            return !sameIds(next.step.ids) || (focusedId !== null && focusedId !== next.sourceId)
                ? stopped
                : waiting;
        }
    }
    const step = Windows.reorderStep(windows, workspace, next.sourceId, next.targetId, next.after);
    if (!step || step.done) return stopped;
    if (next.stage === 'next') {
        next.step = step;
        return step.crossColumn
            ? focus(step.neighborId, 'neighborFocus')
            : focus(next.sourceId, 'sourceFocus');
    }
    if (
        !sameIds(next.step.ids) ||
        step.action !== next.step.action ||
        step.neighborId !== next.step.neighborId
    )
        return stopped;
    if (next.stage === 'neighborFocus' && focusedId === next.step.neighborId)
        return focus(next.sourceId, 'sourceFocus');
    if (next.stage === 'sourceFocus' && focusedId === next.sourceId) {
        next.stage = 'layout';
        return { pending: next, request: { action: step.action } };
    }
    return waiting;
}
