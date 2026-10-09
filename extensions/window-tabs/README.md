# Justin Window Tabs

A local Manifest V3 extension for Helium/Chromium. Newly created tabs in a
normal window containing other tabs are moved into their own normal windows.
Justin Navigation can then show each page as a separate window entry.

## Load in Helium

1. Open `chrome://extensions` in Helium.
2. Enable **Developer mode**.
3. Click **Load unpacked** and select this directory:
   `/var/home/justin/Documents/Projects/justin-shell/extensions/window-tabs`.
4. Pin **Justin Window Tabs** using the browser's Extensions menu.
5. Optionally select **Dynamic** under Settings → Appearance → Browser layout
   to hide Helium's tab strip in single-tab windows.

The toolbar badge starts at **ON**. Click it to pause (**OFF**) or resume.
The preference persists across browser restarts. Reload the extension from
`chrome://extensions` after changing its files. Remove it there to uninstall.
No build, extra service, DMS reload, or shell restart is required.

## Behavior

- Middle-click, Ctrl+click, Ctrl+T, and other actions that create tabs are eligible.
  Ordinary navigation within the current tab is unchanged.
- The existing tab moves; the extension does not reopen its URL, reload its page,
  or close it. Tabs already open when the extension loads are left alone.
- A tab already alone in its window stays there. Popups, app windows, and
  developer-tools windows are excluded. Manually dragging tabs between windows
  is not automatically reversed because it is an attachment, not a creation.
- Background-created tabs request unfocused windows. A foreground-created tab
  requests focus only if it remains active in a focused source window. Niri and
  Wayland activation policies can affect actual focus and placement.
- To enable private windows, turn on **Allow in incognito** in extension details.
  The extension uses split incognito mode and preserves the source's private
  status when creating a destination window. The enabled preference is shared
  between regular and private instances.
- The existing external-link wrapper can stay enabled; a URL already opening
  in its own window needs no additional move.

## Limits and validation

The browser creates the tab before the extension can detach it. A tab-strip
flash or brief focus change is possible. This is a best-effort event handler,
not a browser-level prohibition on multiple tabs. Closing or moving windows
concurrently can race with the final browser operation. An error leaves the
tab under browser control, logs to the service-worker console, and displays a
red **!** badge; click to pause, or reload the extension to refresh its badge.

Newly restored tabs are eligible if Helium emits tab-created events. Restoring
a multi-tab session or opening a folder of bookmarks can therefore create many
windows. Pause before doing either if you want the tabs kept together. Tab
groups, split views, and pinning are not explicitly preserved across detachment.
Login popups are left alone; login flows that create ordinary tabs still need
live verification. No website URL or contents are inspected, and only the
`storage` permission is requested.

Node tests exercise the actual controller with a simulated browser, including
burst events, foreground/background intent, pause persistence, private windows,
closure/manual moves, and API failure recovery. Live Helium installation,
session restore, login flows, and focus behavior on Niri remain unverified.

APIs inspected: [tabs](https://developer.chrome.com/docs/extensions/reference/api/tabs),
[windows](https://developer.chrome.com/docs/extensions/reference/api/windows), and
[storage](https://developer.chrome.com/docs/extensions/reference/api/storage).
