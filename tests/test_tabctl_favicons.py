"""Wire format, image handling, and subscription lifecycle regression tests."""

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location(
    "tabctl_favicons", Path(__file__).resolve().parents[1] / "scripts/tabctl-favicons.py"
)
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class IconTests(unittest.TestCase):
    def test_active_wire_rows_only_with_profile_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            rows = [
                (1, 10, "One", "https://example.com", 0, True, False, "https://example.com/a.svg"),
                (1, 11, "Hidden", "", 1, False, False, "https://example.com/b.png"),
            ]
            tabs = bridge.active_tabs("Helium2", rows, directory)
            self.assertEqual(len(tabs), 1)
            self.assertEqual(tabs[0]["instance"], "Helium2")
            self.assertEqual(tabs[0]["title"], "One")
            self.assertEqual(tabs[0]["iconSource"], "https://example.com/a.svg")

    def test_inline_icons_materialize_and_deduplicate(self):
        with tempfile.TemporaryDirectory() as directory:
            uri = bridge.icon_source("data:image/png;base64,aGVsbG8=", directory)
            self.assertTrue(uri.startswith("file:///"))
            self.assertEqual(next(Path(directory).iterdir()).read_bytes(), b"hello")
            self.assertEqual(uri, bridge.icon_source("data:image/png;base64,aGVsbG8=", directory))
            self.assertEqual(len(list(Path(directory).iterdir())), 1)
            svg = bridge.icon_source("data:image/svg+xml,%3Csvg%2F%3E", directory)
            self.assertTrue(svg.endswith(".svg"))

    def test_missing_invalid_oversized_and_non_web_sources_fall_back(self):
        with tempfile.TemporaryDirectory() as directory:
            for source in (
                None,
                "",
                "file:///etc/passwd",
                "chrome://favicon/a",
                "javascript:alert(1)",
                "https://user:pass@example.com/a",
                "https://",
                "data:text/html,hi",
                "data:image/png;base64,!",
                "data:image/png,",
                "data:image/png," + "x" * 2100000,
            ):
                self.assertEqual(bridge.icon_source(source, directory), "", source)


class Bus:
    def __init__(self):
        self.calls = []

    def call(self, *args):
        self.calls.append(args)

    def call_finish(self, result):
        if isinstance(result, Exception):
            raise result
        return SimpleNamespace(unpack=lambda: (result,))


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = io.StringIO()
        redirect = contextlib.redirect_stdout(self.output)
        redirect.__enter__()
        self.addCleanup(redirect.__exit__, None, None, None)
        self.timers = {}
        self.next_timer = 0
        self.sub = bridge.Subscriber.__new__(bridge.Subscriber)
        self.sub.services = {}
        self.sub.last_snapshot = None
        self.sub.directory = self.temp.name
        self.sub.bus = Bus()
        self.sub.Gio = SimpleNamespace(DBusCallFlags=SimpleNamespace(NONE=0))
        self.sub.GLib = SimpleNamespace(
            VariantType=SimpleNamespace(new=lambda value: value),
            Error=RuntimeError,
            timeout_add=self.timer,
            source_remove=lambda id: self.timers.pop(id),
        )
        self.name = bridge.PREFIX + "Helium"
        self.rows = [(1, 10, "One", "", 0, True, False, "https://example.com/a.png")]

    def timer(self, _delay, callback):
        self.next_timer += 1
        self.timers[self.next_timer] = callback
        return self.next_timer

    def complete(self, index, rows):
        self.sub.bus.calls[index][-1](self.sub.bus, rows)

    def test_inline_files_are_retained_until_no_profile_references_them(self):
        inline = "data:image/png;base64,aGVsbG8="
        rows = [(1, 10, "One", "", 0, True, False, inline)]
        second = bridge.PREFIX + "Helium2"
        self.sub.add(self.name, ":1.1")
        self.complete(0, rows)
        self.sub.add(second, ":1.2")
        self.complete(1, rows)
        self.assertEqual(len(list(Path(self.temp.name).iterdir())), 1)
        self.sub.remove(self.name)
        self.sub.emit()
        self.assertEqual(len(list(Path(self.temp.name).iterdir())), 1)
        self.sub.remove(second)
        self.sub.emit()
        self.assertEqual(list(Path(self.temp.name).iterdir()), [])

    def test_disappearing_startup_profile_does_not_stop_subscription(self):
        live = bridge.PREFIX + "Helium2"

        class StartupBus(Bus):
            def connect(self, *_args):
                pass

            def signal_subscribe(self, *_args):
                pass

            def call_sync(self, *_args):
                method = _args[3]
                if method == "ListNames":
                    value = ([bridge.PREFIX + "Helium", live],)
                elif _args[4] == bridge.PREFIX + "Helium":
                    raise RuntimeError("profile disconnected")
                else:
                    value = (":1.2",)
                return SimpleNamespace(unpack=lambda: value)

        bus = StartupBus()
        gio = SimpleNamespace(
            bus_get_sync=lambda *_args: bus,
            BusType=SimpleNamespace(SESSION=0),
            DBusSignalFlags=SimpleNamespace(NONE=0),
            DBusCallFlags=SimpleNamespace(NONE=0),
        )
        glib = SimpleNamespace(
            Error=RuntimeError,
            Variant=lambda _kind, value: value[0],
            VariantType=SimpleNamespace(new=lambda value: value),
            timeout_add=self.timer,
        )
        subscriber = bridge.Subscriber(gio, glib, self.temp.name)
        self.assertEqual(list(subscriber.services), [live])
        self.assertEqual(len(bus.calls), 1)

    def test_disconnect_clears_snapshot_and_ignores_late_reply(self):
        self.sub.add(self.name, ":1.1")
        self.complete(0, self.rows)
        self.assertIn('"title":"One"', self.output.getvalue())
        self.sub.refresh(self.name, self.sub.services[self.name])
        self.sub.remove(self.name)
        self.sub.emit()
        self.complete(1, self.rows)
        self.assertEqual(self.output.getvalue().splitlines()[-1], "[]")
        self.assertFalse(self.timers)

    def test_owner_replacement_ignores_previous_connection_reply(self):
        self.sub.add(self.name, ":1.1")
        self.sub.add(self.name, ":1.2")
        self.complete(0, self.rows)
        self.assertEqual(self.sub.services[self.name]["tabs"], [])
        self.complete(1, self.rows)
        self.assertEqual(len(self.sub.services[self.name]["tabs"]), 1)

    def test_event_bursts_coalesce_and_delayed_refresh_runs_once(self):
        self.sub.add(self.name, ":1.1")
        path = "/dev/slastra/TabCtl/Browser/Helium"
        for _ in range(3):
            self.sub.tabs_updated(None, ":1.1", path, None, None, None)
        self.assertEqual(len(self.sub.bus.calls), 1)
        self.assertEqual(len(self.timers), 1)
        self.complete(0, self.rows)
        self.assertEqual(len(self.sub.bus.calls), 2)
        self.complete(1, self.rows)
        callback = self.timers.pop(self.next_timer)
        self.assertFalse(callback())
        self.assertEqual(len(self.sub.bus.calls), 3)
        self.complete(2, self.rows)
        self.assertFalse(self.timers)
        self.assertEqual(len(self.output.getvalue().splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
