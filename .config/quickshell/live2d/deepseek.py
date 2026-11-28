#!/usr/bin/env python3
"""DeepSeek-chan desktop character for the Quickshell panel.

Shows the free DeepSeek-chan Live2D model in a transparent layer-shell window in the
bottom-right corner of one monitor. Rendering happens in index.html (PixiJS + Live2D);
this script only owns the window.

Model and Cubism Core are NOT part of this repo. They are read from
~/.var/deepseek-chan-live2d/ (DeepSeek/*.model3.json and live2dcubismcore.min.js).

Usage: deepseek.py --x X --y Y [--layer bottom|top] [--height PX] [--framing upper|full]
  --x/--y   top-left of the target monitor in compositor space (used to pick the monitor)
  --height  window height; the width follows the character's proportions
  --framing upper (head to hips, cut by the screen edge) or full (head to feet)

stdin (one command per line): state <name> | layer bottom|top | cursor X Y | cursor none
  cursor: pointer position in global compositor coordinates while it is over the panel
  (Wayland gives no global pointer position, so Quickshell forwards what it sees)
"""

import argparse
import glob
import json
import os
import sys
from pathlib import Path

# gtk-layer-shell must be loaded before libwayland-client, otherwise the window silently
# never maps. From Python that only works by preloading it, so re-exec once with it.
_LS_LIB = "libgtk-layer-shell.so.0"
if _LS_LIB not in os.environ.get("LD_PRELOAD", ""):
    os.environ["LD_PRELOAD"] = (_LS_LIB + " " + os.environ.get("LD_PRELOAD", "")).strip()
    os.execv(sys.executable, [sys.executable, *sys.argv])

import cairo  # noqa: E402
import gi  # noqa: E402

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, WebKit2  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA = Path.home() / ".var" / "deepseek-chan-live2d"
CORE = DATA / "live2dcubismcore.min.js"
RIGHT_MARGIN = 8


def find_model():
    found = sorted(glob.glob(str(DATA / "*" / "*.model3.json")))
    return Path(found[0]) if found else None


def build_config(model, framing):
    """Model manifest with the motions/expressions VTube Studio keeps outside model3.json."""
    base = model.parent
    settings = json.loads(model.read_text(encoding="utf-8"))
    refs = settings.setdefault("FileReferences", {})
    refs["Motions"] = {
        Path(f).name.removesuffix(".motion3.json"): [{"File": str(Path(f).relative_to(base))}]
        for f in sorted(glob.glob(str(base / "**" / "*.motion3.json"), recursive=True))
    }
    refs["Expressions"] = [
        {"Name": Path(f).name.removesuffix(".exp3.json"), "File": str(Path(f).relative_to(base))}
        for f in sorted(glob.glob(str(base / "**" / "*.exp3.json"), recursive=True))
    ]
    settings["url"] = model.as_uri()
    return {"settings": settings, "core": CORE.as_uri(), "framing": framing}


class Character(Gtk.Window):
    def __init__(self, args, config):
        super().__init__()
        self.set_app_paintable(True)
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        # Layer surfaces ignore the default size and a WebView has no natural size
        ratio = 0.62 if args.framing == "full" else 0.9
        self.set_size_request(round(args.height * ratio), args.height)

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "quickshell-deepseek")
        self.set_layer(args.layer)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, RIGHT_MARGIN)
        self.monitor = self.pick_monitor(args.x, args.y)
        if self.monitor:
            GtkLayerShell.set_monitor(self, self.monitor)

        manager = WebKit2.UserContentManager()
        manager.add_script(WebKit2.UserScript(
            "window.DS_CONFIG = " + json.dumps(config) + ";",
            WebKit2.UserContentInjectedFrames.TOP_FRAME,
            WebKit2.UserScriptInjectionTime.START, None, None))
        manager.register_script_message_handler("ds")
        manager.connect("script-message-received::ds", self.on_message)

        self.view = WebKit2.WebView.new_with_user_content_manager(manager)
        s = self.view.get_settings()
        s.set_enable_webgl(True)
        s.set_allow_file_access_from_file_urls(True)
        s.set_allow_universal_access_from_file_urls(True)
        s.set_enable_developer_extras(bool(os.environ.get("DS_DEBUG")))
        s.set_enable_write_console_messages_to_stdout(bool(os.environ.get("DS_DEBUG")))
        s.set_hardware_acceleration_policy(WebKit2.HardwareAccelerationPolicy.ALWAYS)
        self.view.set_background_color(Gdk.RGBA(0, 0, 0, 0))
        self.view.connect("context-menu", lambda *a: True)
        self.add(self.view)

        # Nothing is clickable until the page reports the character's bounds
        self.connect("realize", lambda *_: self.set_input([]))
        self.view.load_uri((HERE / "index.html").as_uri())

        GLib.io_add_watch(GLib.IOChannel.unix_new(sys.stdin.fileno()),
                          GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, self.on_stdin)

    def set_layer(self, name):
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP if name == "top" else GtkLayerShell.Layer.BOTTOM)

    @staticmethod
    def pick_monitor(x, y):
        display = Gdk.Display.get_default()
        for i in range(display.get_n_monitors()):
            m = display.get_monitor(i)
            g = m.get_geometry()
            if g.x == x and g.y == y:
                return m
        return None

    def set_input(self, rects):
        region = cairo.Region([cairo.RectangleInt(*r) for r in rects]) if rects else cairo.Region()
        self.input_shape_combine_region(region)

    def forward_cursor(self, args):
        """Global pointer position -> page coordinates (the window sits in the monitor's
        bottom-right corner, RIGHT_MARGIN from the edge)."""
        if len(args) != 2:
            pos = "null"
        else:
            monitor = self.monitor or Gdk.Display.get_default().get_monitor_at_window(self.get_window())
            g = monitor.get_geometry()
            w, h = self.get_allocated_width(), self.get_allocated_height()
            x0, y0 = g.x + g.width - RIGHT_MARGIN - w, g.y + g.height - h
            try:
                pos = json.dumps([int(args[0]) - x0, int(args[1]) - y0])
            except ValueError:
                return
        self.view.evaluate_javascript(f"window.dsCursor && dsCursor({pos})", -1, None, None, None, None, None)

    def on_message(self, _manager, result):
        try:
            msg = json.loads(result.get_js_value().to_string())
        except (ValueError, AttributeError):
            return
        if msg.get("type") == "input":
            self.set_input([tuple(int(v) for v in r) for r in msg.get("rects", [])])
        elif msg.get("type") == "log":
            print("page:", msg.get("text"), flush=True)

    def on_stdin(self, channel, condition):
        if condition & GLib.IO_HUP:
            Gtk.main_quit()
            return False
        line = sys.stdin.readline()
        if not line:
            Gtk.main_quit()
            return False
        parts = line.split()
        if len(parts) == 2 and parts[0] == "layer":
            self.set_layer(parts[1])
        elif parts and parts[0] == "js" and os.environ.get("DS_DEBUG"):
            self.view.evaluate_javascript(line[3:], -1, None, None, None, None, None)
        elif parts and parts[0] == "cursor":
            self.forward_cursor(parts[1:])
        elif len(parts) == 2 and parts[0] == "state":
            self.view.evaluate_javascript(f"window.dsState && dsState({json.dumps(parts[1])})",
                                          -1, None, None, None, None, None)
        return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--x", type=int, default=0)
    p.add_argument("--y", type=int, default=0)
    p.add_argument("--layer", choices=["bottom", "top"], default="bottom")
    p.add_argument("--height", type=int, default=560)
    p.add_argument("--framing", choices=["upper", "full"], default="upper")
    args = p.parse_args()

    model = find_model()
    if not model or not CORE.exists():
        print(f"deepseek: model or Cubism Core missing in {DATA}", file=sys.stderr)
        sys.exit(2)

    win = Character(args, build_config(model, args.framing))
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
