"""Global pointer position on Wayland via ext-image-copy-capture cursor sessions.

Wayland only tells a client where the pointer is while it is over that client's own
surfaces. COSMIC (and other compositors with ext-image-copy-capture-v1) can report the
pointer position on an output through a cursor session, without capturing any image:
  ext_output_image_capture_source_manager_v1.create_source(output)
  ext_image_copy_capture_manager_v1.create_pointer_cursor_session(source, pointer)
  -> enter / leave / position(x, y) events per output

This speaks the Wayland wire protocol directly over its own connection (no extra Python
packages), driven from the GLib main loop.
"""

import os
import socket
import struct

from gi.repository import GLib


def _wstr(text):
    b = text.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)


class PointerWatch:
    """Calls on_move(x, y) with the pointer in global compositor coordinates,
    on_move(None, None) when it is on no output."""

    def __init__(self, on_move):
        self.on_move = on_move
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        path = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
        if not path.startswith("/"):
            path = os.path.join(os.environ["XDG_RUNTIME_DIR"], path)
        self.sock.connect(path)
        self.sock.setblocking(False)
        self.buf = b""
        self.next_id = 1
        self.globals = {}          # interface -> [(name, version)]
        self.outputs = {}          # wl_output id -> {"x", "y", "scale"}
        self.sessions = {}         # cursor session id -> wl_output id
        self.current = None        # output the pointer is on
        self.registry = self._new()
        self._send(1, 1, struct.pack("<I", self.registry))   # wl_display.get_registry
        self.sync = self._new()
        self._send(1, 0, struct.pack("<I", self.sync))       # wl_display.sync
        self.ready = False
        GLib.io_add_watch(self.sock.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, self._on_io)

    @property
    def supported(self):
        return self.ready and bool(self.sessions)

    def _new(self):
        self.next_id += 1
        return self.next_id

    def _send(self, obj, op, payload=b""):
        self.sock.sendall(struct.pack("<IHH", obj, op, 8 + len(payload)) + payload)

    def _bind(self, iface, index, version):
        name, available = self.globals[iface][index]
        obj = self._new()
        self._send(self.registry, 0, struct.pack("<I", name) + _wstr(iface)
                   + struct.pack("<II", min(version, available), obj))
        return obj

    def _setup(self):
        needed = ("wl_seat", "wl_output", "ext_image_copy_capture_manager_v1",
                  "ext_output_image_capture_source_manager_v1")
        if not all(i in self.globals for i in needed):
            return
        seat = self._bind("wl_seat", 0, 5)
        capture = self._bind("ext_image_copy_capture_manager_v1", 0, 1)
        sources = self._bind("ext_output_image_capture_source_manager_v1", 0, 1)
        pointer = self._new()
        self._send(seat, 0, struct.pack("<I", pointer))      # wl_seat.get_pointer
        for i in range(len(self.globals["wl_output"])):
            out = self._bind("wl_output", i, 4)
            self.outputs[out] = {"x": 0, "y": 0, "scale": 1}
            src = self._new()
            self._send(sources, 0, struct.pack("<II", src, out))
            session = self._new()
            self._send(capture, 1, struct.pack("<III", session, src, pointer))
            self.sessions[session] = out

    def _on_io(self, _fd, condition):
        if condition & GLib.IO_HUP:
            return False
        try:
            data = self.sock.recv(65536)
        except BlockingIOError:
            return True
        if not data:
            return False
        self.buf += data
        while len(self.buf) >= 8:
            obj, op, size = struct.unpack("<IHH", self.buf[:8])
            if len(self.buf) < size:
                break
            body, self.buf = self.buf[8:size], self.buf[size:]
            self._event(obj, op, body)
        return True

    def _event(self, obj, op, body):
        if obj == self.registry and op == 0:                 # wl_registry.global
            name, length = struct.unpack("<II", body[:8])
            iface = body[8:8 + length - 1].decode()
            version = struct.unpack("<I", body[8 + ((length + 3) & ~3):][:4])[0]
            self.globals.setdefault(iface, []).append((name, version))
        elif obj == self.sync and not self.ready:            # registry listed
            self.ready = True
            self._setup()
        elif obj in self.outputs:
            if op == 0:                                      # wl_output.geometry
                x, y = struct.unpack("<ii", body[:8])
                self.outputs[obj].update(x=x, y=y)
            elif op == 3:                                    # wl_output.scale
                self.outputs[obj]["scale"] = max(1, struct.unpack("<i", body[:4])[0])
        elif obj in self.sessions:
            out = self.sessions[obj]
            if op == 0:                                      # enter
                self.current = out
            elif op == 1:                                    # leave
                if self.current == out:
                    self.current = None
                    self.on_move(None, None)
            elif op == 2:                                    # position (output buffer coords)
                self.current = out
                x, y = struct.unpack("<ii", body[:8])
                o = self.outputs[out]
                self.on_move(o["x"] + x / o["scale"], o["y"] + y / o["scale"])
        elif obj == 1 and op == 0:                           # wl_display.error
            print("pointer: wayland error", body[12:].split(b"\0")[0].decode(errors="replace"), flush=True)
