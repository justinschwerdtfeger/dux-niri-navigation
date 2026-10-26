"""Stream Helium active-tab favicons as JSON lines from TabCtl D-Bus events.

Read-only: never activates tabs/windows or opens another compositor connection.
Requires system Python with PyGObject (Gio). Remote icons are loaded by QML;
inline data images are materialized in a private temporary directory.
"""

import base64
import binascii
import hashlib
import json
import re
import signal
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote_to_bytes, urlsplit

PREFIX = "dev.slastra.TabCtl."
INTERFACE = "dev.slastra.TabCtl.Browser"
SERVICE = re.compile(r"^dev\.slastra\.TabCtl\.Helium(?:[2-9]|1[0-6])?$")
MAX_INLINE_SIZE = 1024 * 1024


def icon_source(value, directory):
    """Accept browser-provided web images or bounded inline image data only."""
    if not isinstance(value, str) or not value:
        return ""
    try:
        url = urlsplit(value)
        if url.scheme in ("http", "https") and url.hostname and not url.username:
            return value
        if not value.startswith("data:image/") or len(value) > MAX_INLINE_SIZE * 2:
            return ""
        header, payload = value.split(",", 1)
        mime = header[5:].split(";", 1)[0]
        extensions = {
            "image/png": ".png",
            "image/jpeg": ".jpg",
            "image/gif": ".gif",
            "image/webp": ".webp",
            "image/svg+xml": ".svg",
            "image/x-icon": ".ico",
            "image/vnd.microsoft.icon": ".ico",
        }
        if mime not in extensions:
            return ""
        encoded = unquote_to_bytes(payload)
        data = base64.b64decode(encoded, validate=True) if header.endswith(";base64") else encoded
        if not data or len(data) > MAX_INLINE_SIZE:
            return ""
        path = Path(directory) / (hashlib.sha256(data).hexdigest() + extensions[mime])
        if not path.exists():
            path.write_bytes(data)
        return path.as_uri()
    except (ValueError, OSError, binascii.Error):
        return ""


def active_tabs(instance, rows, directory):
    """Project the inspected ListTabsWithIcons a(iissibbs) wire shape."""
    tabs = []
    for row in rows:
        if len(row) != 8 or row[5] is not True:
            continue
        window_id, tab_id, title, _url, _index, _active, _pinned, favicon = row
        tabs.append(
            {
                "browser": "Helium",
                "instance": instance,
                "windowId": window_id,
                "tabId": tab_id,
                "title": title,
                "iconSource": icon_source(favicon, directory),
            }
        )
    return tabs


class Subscriber:
    def __init__(self, Gio, GLib, directory):
        self.Gio, self.GLib, self.directory = Gio, GLib, directory
        self.services = {}
        self.last_snapshot = None
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.bus.connect("closed", self.closed)
        self.bus.signal_subscribe(
            "org.freedesktop.DBus",
            "org.freedesktop.DBus",
            "NameOwnerChanged",
            "/org/freedesktop/DBus",
            None,
            Gio.DBusSignalFlags.NONE,
            self.owner_changed,
        )
        self.bus.signal_subscribe(
            None, INTERFACE, "TabsUpdated", None, None, Gio.DBusSignalFlags.NONE, self.tabs_updated
        )
        names = self.bus.call_sync(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "ListNames",
            None,
            GLib.VariantType.new("(as)"),
            Gio.DBusCallFlags.NONE,
            3000,
            None,
        ).unpack()[0]
        for name in names:
            if SERVICE.fullmatch(name):
                try:
                    owner = self.bus.call_sync(
                        "org.freedesktop.DBus",
                        "/org/freedesktop/DBus",
                        "org.freedesktop.DBus",
                        "GetNameOwner",
                        GLib.Variant("(s)", (name,)),
                        None,
                        Gio.DBusCallFlags.NONE,
                        3000,
                        None,
                    ).unpack()[0]
                except GLib.Error:
                    # A profile can disappear between ListNames and GetNameOwner.
                    # Keep subscribing to the other profiles and future owners.
                    continue
                self.add(name, owner)
        self.emit()

    def closed(self, *_args):
        print("[]", flush=True)
        raise SystemExit("session bus disconnected")

    def emit(self):
        tabs = [tab for name in sorted(self.services) for tab in self.services[name]["tabs"]]
        snapshot = json.dumps(tabs, ensure_ascii=True, separators=(",", ":"))
        if snapshot != self.last_snapshot:
            print(snapshot, flush=True)
            self.last_snapshot = snapshot
            # Inline files otherwise accumulate for the entire shell session.
            # Only delete our own files once no profile references their URI.
            live_sources = {tab["iconSource"] for tab in tabs}
            for path in Path(self.directory).iterdir():
                if path.as_uri() not in live_sources:
                    path.unlink(missing_ok=True)

    def add(self, name, owner):
        self.remove(name)
        state = {"owner": owner, "tabs": [], "busy": False, "again": False, "timer": 0}
        self.services[name] = state
        self.refresh(name, state)
        self.delayed_refresh(name, state)

    def remove(self, name):
        state = self.services.pop(name, None)
        if state and state["timer"]:
            self.GLib.source_remove(state["timer"])

    def owner_changed(self, _bus, _sender, _path, _iface, _signal, parameters):
        name, _old, new = parameters.unpack()
        if not SERVICE.fullmatch(name):
            return
        if new:
            self.add(name, new)
        else:
            self.remove(name)
        self.emit()

    def tabs_updated(self, _bus, sender, path, _iface, _signal, _parameters):
        for name, state in list(self.services.items()):
            if (
                sender == state["owner"]
                and path == "/dev/slastra/TabCtl/Browser/" + name[len(PREFIX) :]
            ):
                self.refresh(name, state)
                self.delayed_refresh(name, state)

    def delayed_refresh(self, name, state):
        # Extension 2.3.0 omits favicon-only onUpdated notifications. Re-read
        # once after tab churn, allowing an asynchronously resolved icon to land.
        if state["timer"]:
            self.GLib.source_remove(state["timer"])

        def refresh_later():
            state["timer"] = 0
            self.refresh(name, state)
            return False

        state["timer"] = self.GLib.timeout_add(2000, refresh_later)

    def refresh(self, name, state):
        if self.services.get(name) is not state:
            return
        if state["busy"]:
            state["again"] = True
            return
        state["busy"] = True
        instance = name[len(PREFIX) :]

        def finished(bus, result):
            if self.services.get(name) is not state:
                return  # old connection's reply must not repopulate a new owner
            try:
                rows = bus.call_finish(result).unpack()[0]
                state["tabs"] = active_tabs(instance, rows, self.directory)
            except self.GLib.Error as error:
                state["tabs"] = []
                print(f"{instance}: {error.message}", file=sys.stderr, flush=True)
            state["busy"] = False
            self.emit()
            if state["again"]:
                state["again"] = False
                self.refresh(name, state)

        self.bus.call(
            state["owner"],
            "/dev/slastra/TabCtl/Browser/" + instance,
            INTERFACE,
            "ListTabsWithIcons",
            None,
            self.GLib.VariantType.new("(a(iissibbs))"),
            self.Gio.DBusCallFlags.NONE,
            3000,
            None,
            finished,
        )


def main():
    from gi.repository import Gio, GLib

    try:
        from gi.repository import GLibUnix

        signal_add = GLibUnix.signal_add
    except ImportError:
        signal_add = GLib.unix_signal_add

    with tempfile.TemporaryDirectory(prefix="dux-niri-navigation-favicons-") as directory:
        Subscriber(Gio, GLib, directory)
        loop = GLib.MainLoop()
        signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, loop.quit)
        signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, loop.quit)
        loop.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("[]", flush=True)
        print(str(error), file=sys.stderr)
        sys.exit(1)
