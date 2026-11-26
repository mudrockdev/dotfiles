#!/usr/bin/env python3
"""COSMIC pencere listesi yardımcısı (bağımlılıksız, saf Wayland wire protokolü).

COSMIC, Quickshell'in ToplevelManager'ının kullandığı wlr-foreign-toplevel
protokolünü sunmuyor. Bu betik şunları konuşur:
  - ext_foreign_toplevel_list_v1   (pencere listesi, app_id, başlık)
  - zcosmic_toplevel_info_v1 (v2+) (durum: odakta / küçültülmüş / ...)
  - zcosmic_toplevel_manager_v1    (etkinleştir / küçült / kapat)

Çıktı (stdout): her değişiklikte tek satır JSON dizisi:
  [{"id": 4278190080, "appId": "...", "title": "...", "activated": true,
    "minimized": false, "maximized": false, "fullscreen": false}, ...]

Girdi (stdin): satır başına bir komut:
  activate <id> | minimize <id> | unminimize <id> | close <id>
"""

import json
import os
import select
import socket
import struct
import sys

# --- arayüz/opcode tabloları -------------------------------------------------
WL_DISPLAY_SYNC, WL_DISPLAY_GET_REGISTRY = 0, 1
WL_DISPLAY_EV_ERROR, WL_DISPLAY_EV_DELETE_ID = 0, 1
WL_REGISTRY_BIND = 0
WL_REGISTRY_EV_GLOBAL, WL_REGISTRY_EV_GLOBAL_REMOVE = 0, 1
WL_CALLBACK_EV_DONE = 0

EXT_LIST_EV_TOPLEVEL, EXT_LIST_EV_FINISHED = 0, 1
EXT_HANDLE_DESTROY = 0
EXT_HANDLE_EV_CLOSED, EXT_HANDLE_EV_DONE, EXT_HANDLE_EV_TITLE, EXT_HANDLE_EV_APP_ID = 0, 1, 2, 3

COSMIC_INFO_GET_COSMIC_TOPLEVEL = 1
COSMIC_HANDLE_DESTROY = 0
COSMIC_HANDLE_EV_STATE = 8
STATE_MAXIMIZED, STATE_MINIMIZED, STATE_ACTIVATED, STATE_FULLSCREEN = 0, 1, 2, 3

MGR_CLOSE, MGR_ACTIVATE, MGR_SET_MINIMIZED, MGR_UNSET_MINIMIZED = 1, 2, 5, 6


class Wayland:
    def __init__(self):
        name = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
        path = name if name.startswith("/") else os.path.join(os.environ["XDG_RUNTIME_DIR"], name)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.next_id = 2
        self.buf = b""

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    @staticmethod
    def _string(s):
        b = s.encode() + b"\0"
        return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)

    def send(self, obj, opcode, *args):
        payload = b""
        for a in args:
            payload += self._string(a) if isinstance(a, str) else struct.pack("<I", a & 0xFFFFFFFF)
        size = 8 + len(payload)
        self.sock.sendall(struct.pack("<II", obj, (size << 16) | opcode) + payload)

    def read(self):
        data = self.sock.recv(65536)
        if not data:
            raise ConnectionError("compositor bağlantıyı kapattı")
        self.buf += data
        msgs = []
        while len(self.buf) >= 8:
            obj, word = struct.unpack_from("<II", self.buf)
            size, opcode = word >> 16, word & 0xFFFF
            if len(self.buf) < size:
                break
            msgs.append((obj, opcode, self.buf[8:size]))
            self.buf = self.buf[size:]
        return msgs


def get_uint(p, off):
    return struct.unpack_from("<I", p, off)[0], off + 4


def get_string(p, off):
    n, off = get_uint(p, off)
    s = p[off:off + n - 1].decode(errors="replace") if n else ""
    return s, off + n + (-n % 4)


def get_array(p, off):
    n, off = get_uint(p, off)
    return p[off:off + n], off + n + (-n % 4)


class Toplevels:
    def __init__(self):
        self.wl = Wayland()
        self.registry = self.wl.new_id()
        self.wl.send(1, WL_DISPLAY_GET_REGISTRY, self.registry)
        self.globals = {}
        self.list = self.info = self.mgr = self.seat = None
        self.handles = {}       # ext handle id -> dict
        self.cosmic_to_ext = {}  # cosmic handle id -> ext handle id
        self.dirty = True

    def bind(self, iface, max_version):
        if iface not in self.globals:
            return None
        name, ver = self.globals[iface]
        oid = self.wl.new_id()
        self.wl.send(self.registry, WL_REGISTRY_BIND, name, iface, min(ver, max_version), oid)
        return oid

    def roundtrip_globals(self):
        cb = self.wl.new_id()
        self.wl.send(1, WL_DISPLAY_SYNC, cb)
        done = False
        while not done:
            for obj, op, p in self.wl.read():
                if obj == cb and op == WL_CALLBACK_EV_DONE:
                    done = True
                else:
                    self.dispatch(obj, op, p)
        if "ext_foreign_toplevel_list_v1" not in self.globals or "zcosmic_toplevel_info_v1" not in self.globals:
            sys.exit("ext_foreign_toplevel_list_v1 / zcosmic_toplevel_info_v1 bulunamadı (COSMIC değil mi?)")
        if self.globals["zcosmic_toplevel_info_v1"][1] < 2:
            sys.exit("zcosmic_toplevel_info_v1 sürümü < 2")
        self.info = self.bind("zcosmic_toplevel_info_v1", 3)
        self.mgr = self.bind("zcosmic_toplevel_manager_v1", 4)
        self.seat = self.bind("wl_seat", 1)
        self.list = self.bind("ext_foreign_toplevel_list_v1", 1)

    def dispatch(self, obj, op, p):
        if obj == 1:
            if op == WL_DISPLAY_EV_ERROR:
                oid, off = get_uint(p, 0)
                code, off = get_uint(p, off)
                msg, _ = get_string(p, off)
                sys.exit(f"wayland hatası: nesne {oid} kod {code}: {msg}")
            return
        if obj == self.registry:
            if op == WL_REGISTRY_EV_GLOBAL:
                name, off = get_uint(p, 0)
                iface, off = get_string(p, off)
                ver, _ = get_uint(p, off)
                self.globals.setdefault(iface, (name, ver))
            return
        if obj == self.list:
            if op == EXT_LIST_EV_TOPLEVEL:
                hid, _ = get_uint(p, 0)
                cid = self.wl.new_id()
                self.wl.send(self.info, COSMIC_INFO_GET_COSMIC_TOPLEVEL, cid, hid)
                self.handles[hid] = {"id": hid, "cosmic": cid, "appId": "", "title": "",
                                     "activated": False, "minimized": False,
                                     "maximized": False, "fullscreen": False}
                self.cosmic_to_ext[cid] = hid
            elif op == EXT_LIST_EV_FINISHED:
                sys.exit(0)
            return
        h = self.handles.get(obj)
        if h is not None:
            if op == EXT_HANDLE_EV_TITLE:
                h["title"], _ = get_string(p, 0)
            elif op == EXT_HANDLE_EV_APP_ID:
                h["appId"], _ = get_string(p, 0)
            elif op == EXT_HANDLE_EV_CLOSED:
                self.wl.send(h["cosmic"], COSMIC_HANDLE_DESTROY)
                self.wl.send(obj, EXT_HANDLE_DESTROY)
                self.cosmic_to_ext.pop(h["cosmic"], None)
                del self.handles[obj]
            self.dirty = True
            return
        hid = self.cosmic_to_ext.get(obj)
        if hid is not None and op == COSMIC_HANDLE_EV_STATE:
            arr, _ = get_array(p, 0)
            states = set(struct.unpack(f"<{len(arr) // 4}I", arr))
            h = self.handles[hid]
            h["activated"] = STATE_ACTIVATED in states
            h["minimized"] = STATE_MINIMIZED in states
            h["maximized"] = STATE_MAXIMIZED in states
            h["fullscreen"] = STATE_FULLSCREEN in states
            self.dirty = True

    def command(self, line):
        parts = line.split()
        if len(parts) != 2 or not parts[1].isdigit() or self.mgr is None:
            return
        h = self.handles.get(int(parts[1]))
        if h is None:
            return
        cmd, c = parts[0], h["cosmic"]
        if cmd == "activate":
            if h["minimized"]:
                self.wl.send(self.mgr, MGR_UNSET_MINIMIZED, c)
            self.wl.send(self.mgr, MGR_ACTIVATE, c, self.seat)
        elif cmd == "minimize":
            self.wl.send(self.mgr, MGR_SET_MINIMIZED, c)
        elif cmd == "unminimize":
            self.wl.send(self.mgr, MGR_UNSET_MINIMIZED, c)
        elif cmd == "close":
            self.wl.send(self.mgr, MGR_CLOSE, c)

    def emit(self):
        if not self.dirty:
            return
        self.dirty = False
        out = [{k: v for k, v in h.items() if k != "cosmic"} for h in self.handles.values()]
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    def run(self):
        self.roundtrip_globals()
        stdin_open = True
        pending = b""
        while True:
            fds = [self.wl.sock] + ([0] if stdin_open else [])
            ready, _, _ = select.select(fds, [], [], None if not self.dirty else 0.03)
            if self.wl.sock in ready:
                for obj, op, p in self.wl.read():
                    self.dispatch(obj, op, p)
            if 0 in ready:
                chunk = os.read(0, 4096)
                if not chunk:
                    stdin_open = False
                pending += chunk
                *lines, pending = pending.split(b"\n")
                for line in lines:
                    self.command(line.decode(errors="replace").strip())
            if not ready:
                self.emit()  # kısa süre sessiz kaldıysa toplu halde yayınla


if __name__ == "__main__":
    try:
        Toplevels().run()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
