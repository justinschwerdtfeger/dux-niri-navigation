// No page URLs, content scripts, polling, or native messaging are needed.
export function registerWindowTabs(api, logError = console.error) {
    let queue = Promise.resolve();

    const enabled = async () =>
        (await api.storage.local.get({ enabled: true })).enabled !== false;

    async function showState() {
        const on = await enabled();
        await api.action.setBadgeText({ text: on ? 'ON' : 'OFF' });
        await api.action.setBadgeBackgroundColor({ color: on ? '#276749' : '#555555' });
        await api.action.setTitle({ title: `Justin Window Tabs: ${on ? 'on — click to pause' : 'paused — click to resume'}` });
    }

    async function report(error) {
        logError('Justin Window Tabs:', error);
        // Never close or recreate a tab to recover from a failed move.
        try {
            await api.action.setBadgeText({ text: '!' });
            await api.action.setBadgeBackgroundColor({ color: '#a52828' });
            await api.action.setTitle({ title: 'Justin Window Tabs: action failed; see extension service-worker console. Click to pause.' });
        } catch (badgeError) {
            logError('Justin Window Tabs badge:', badgeError);
        }
    }

    function enqueue(task) {
        // Serializing keeps burst handlers from detaching a source's final tab.
        // Catch each failure so subsequent events still run.
        queue = queue.then(task).catch(report);
        return queue;
    }

    async function detach(created) {
        if (!Number.isInteger(created.id) || !Number.isInteger(created.windowId)
                || !(await enabled())) return;

        let tab;
        let source;
        let siblings;
        try {
            tab = await api.tabs.get(created.id);
            // A user may already have moved/closed the tab while it was queued.
            if (tab.windowId !== created.windowId) return;
            source = await api.windows.get(tab.windowId);
            if (source.type !== 'normal') return;
            siblings = await api.tabs.query({ windowId: source.id });
        } catch (error) {
            // Disappearing tabs/windows are normal, not a reason to retry by URL.
            // Report other failures rather than silently treating them as closure.
            if (/No tab with id|No window with id|Invalid tab ID|Invalid window ID/i.test(String(error))) return;
            throw error;
        }
        if (siblings.length < 2 || !siblings.some(other => other.id === tab.id)) return;

        // Recheck after querying: don't move a tab manually detached in the meantime.
        try {
            tab = await api.tabs.get(created.id);
            source = await api.windows.get(source.id);
        } catch (error) {
            if (/No tab with id|No window with id|Invalid tab ID|Invalid window ID/i.test(String(error))) return;
            throw error;
        }
        if (tab.windowId !== source.id || !(await enabled())) return;

        await api.windows.create({
            tabId: tab.id,
            type: 'normal',
            incognito: source.incognito,
            // The creation-time flag preserves middle-click's background intent.
            focused: Boolean(created.active && tab.active && source.focused)
        });
    }

    api.tabs.onCreated.addListener(tab => enqueue(() => detach(tab)));
    api.action.onClicked.addListener(() => enqueue(async () => {
        await api.storage.local.set({ enabled: !(await enabled()) });
        await showState();
    }));
    api.runtime.onInstalled.addListener(() => enqueue(showState));
    api.runtime.onStartup.addListener(() => enqueue(showState));
    api.storage.onChanged.addListener((changes, area) => {
        if (area === 'local' && changes.enabled) enqueue(showState);
    });
    // Refresh the badge when the MV3 worker wakes, without sweeping existing tabs.
    enqueue(showState);

    return { whenIdle: () => queue };
}
