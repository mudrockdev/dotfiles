#!/usr/bin/env python3
"""COSMIC pencere listesi + önizleme yardımcısı (bağımlılıksız, saf Wayland wire protokolü).

COSMIC, Quickshell'in ToplevelManager'ının kullandığı wlr-foreign-toplevel
protokolünü sunmuyor. Bu betik şunları konuşur:
  - ext_foreign_toplevel_list_v1                       (pencere listesi, app_id, başlık)
  - zcosmic_toplevel_info_v1 (v2+)                     (odakta / küçültülmüş / ...)
  - zcosmic_toplevel_manager_v1                        (etkinleştir / küçült / kapat)
  - ext_workspace_manager_v1 + wl_output               (pencerenin çalışma alanı / çıkışı)
  - ext_foreign_toplevel_image_capture_source_manager_v1 +
    ext_image_copy_capture_manager_v1 + wl_shm          (pencere önizlemesi)

Çıktı (stdout), satır başına bir JSON nesnesi:
  {"type": "toplevels", "list": [{"id", "appId", "title", "activated",
                                  "minimized", "maximized", "fullscreen", "stack",
                                  "workspaces": [{"id", "name", "outputs": [...]}, ...],
                                  "geometry": {"output", "x", "y", "w", "h"} | null}, ...]}
  {"type": "preview", "id": <id>, "path": "<dosya>", "ok": true|false}

"stack": pencerenin en son odaklandığı sıra (büyük = üstte). COSMIC yığın sırasını bildirmiyor;
odaklanan pencere öne geldiği için odak geçmişi kullanılır. Geçmiş, pencerenin kalıcı
kimliğiyle (ext_foreign_toplevel identifier) $XDG_RUNTIME_DIR/quickshell-previews/stack.json
içinde tutulur; betik yeniden başlasa da sıra korunur.

Girdi (stdin), satır başına bir komut:
  activate <id> | minimize <id> | unminimize <id> | close <id>
  capture <id> <yol.ppm> <max_genişlik> <max_yükseklik>
"""

import json
import math
import mmap
import os
import select
import socket
import struct
import sys

# --- opcode tabloları -------------------------------------------------------
WL_DISPLAY_SYNC, WL_DISPLAY_GET_REGISTRY = 0, 1
WL_DISPLAY_EV_ERROR = 0
WL_REGISTRY_BIND = 0
WL_REGISTRY_EV_GLOBAL = 0
WL_CALLBACK_EV_DONE = 0
WL_SHM_CREATE_POOL = 0
WL_SHM_POOL_CREATE_BUFFER, WL_SHM_POOL_DESTROY = 0, 1
WL_BUFFER_DESTROY = 0
# wl_shm biçimi -> bellekteki (R, G, B) bayt konumları
SHM_FORMATS = {
    0x34324258: (0, 1, 2),  # XBGR8888: R G B X
    0x34324241: (0, 1, 2),  # ABGR8888: R G B A
    1: (2, 1, 0),           # XRGB8888: B G R X
    0: (2, 1, 0),           # ARGB8888: B G R A
    0x34325258: (2, 1, 0),  # XRGB8888 (fourcc)
    0x34325241: (2, 1, 0),  # ARGB8888 (fourcc)
}

EXT_LIST_EV_TOPLEVEL, EXT_LIST_EV_FINISHED = 0, 1
EXT_HANDLE_DESTROY = 0
EXT_HANDLE_EV_CLOSED, EXT_HANDLE_EV_TITLE, EXT_HANDLE_EV_APP_ID, EXT_HANDLE_EV_IDENTIFIER = 0, 2, 3, 4

COSMIC_INFO_GET_COSMIC_TOPLEVEL = 1
COSMIC_HANDLE_DESTROY = 0
COSMIC_HANDLE_EV_STATE = 8
COSMIC_HANDLE_EV_GEOMETRY = 9              # v2+: output, x, y, w, h (çıkışa göre mantıksal)
COSMIC_HANDLE_EV_EXT_WS_ENTER, COSMIC_HANDLE_EV_EXT_WS_LEAVE = 10, 11  # v2+

WS_MGR_EV_GROUP, WS_MGR_EV_WORKSPACE = 0, 1
WS_GROUP_EV_OUTPUT_ENTER, WS_GROUP_EV_OUTPUT_LEAVE = 1, 2
WS_GROUP_EV_WS_ENTER, WS_GROUP_EV_WS_LEAVE, WS_GROUP_EV_REMOVED = 3, 4, 5
WS_EV_ID, WS_EV_NAME, WS_EV_REMOVED = 0, 1, 5
WS_GROUP_DESTROY, WS_DESTROY = 1, 0

WL_OUTPUT_EV_NAME = 4
STATE_MAXIMIZED, STATE_MINIMIZED, STATE_ACTIVATED, STATE_FULLSCREEN = 0, 1, 2, 3

MGR_CLOSE, MGR_ACTIVATE, MGR_SET_MINIMIZED, MGR_UNSET_MINIMIZED = 1, 2, 5, 6

SRC_MGR_CREATE_SOURCE = 0
SRC_DESTROY = 0
COPY_MGR_CREATE_SESSION = 0
SESSION_CREATE_FRAME, SESSION_DESTROY = 0, 1
SESSION_EV_BUFFER_SIZE, SESSION_EV_SHM_FORMAT, SESSION_EV_DONE, SESSION_EV_STOPPED = 0, 1, 4, 5
FRAME_DESTROY, FRAME_ATTACH_BUFFER, FRAME_DAMAGE_BUFFER, FRAME_CAPTURE = 0, 1, 2, 3
FRAME_EV_READY, FRAME_EV_FAILED = 3, 4


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

    def send(self, obj, opcode, *args, fd=None):
        payload = b""
        for a in args:
            payload += self._string(a) if isinstance(a, str) else struct.pack("<I", a & 0xFFFFFFFF)
        data = struct.pack("<II", obj, ((8 + len(payload)) << 16) | opcode) + payload
        if fd is None:
            self.sock.sendall(data)
        else:
            self.sock.sendmsg([data], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, struct.pack("i", fd))])

    def read(self):
        data = self.sock.recv(65536)
        if not data:
            raise ConnectionError("compositor closed the connection")
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


def write_ppm(path, mm, width, height, order, max_w, max_h):
    """32bpp tamponu tamsayı adımlı en-yakın-komşu ile küçültüp PPM (P6) yazar."""
    k = max(1, math.ceil(max(width / max_w, height / max_h)))
    ow, oh = width // k, height // k
    px = memoryview(mm).cast("I")
    try:
        pixels = b"".join(px[y * k * width:y * k * width + ow * k:k].tobytes() for y in range(oh))
    finally:
        px.release()
    rgb = bytearray(ow * oh * 3)
    r, g, b = order
    rgb[0::3], rgb[1::3], rgb[2::3] = pixels[r::4], pixels[g::4], pixels[b::4]
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(b"P6\n%d %d\n255\n" % (ow, oh) + rgb)
    os.replace(tmp, path)


class Toplevels:
    def __init__(self):
        self.wl = Wayland()
        self.registry = self.wl.new_id()
        self.wl.send(1, WL_DISPLAY_GET_REGISTRY, self.registry)
        self.globals = {}
        self.list = self.info = self.mgr = self.seat = None
        self.shm = self.src_mgr = self.copy_mgr = None
        self.handles = {}        # ext handle id -> dict
        self.cosmic_to_ext = {}  # cosmic handle id -> ext handle id
        self.captures = {}       # session/frame id -> capture durumu
        self.output_globals = []  # (name, version) — bağlanmadan önce
        self.outputs = {}         # wl_output nesne id -> bağlayıcı adı (ör. "DP-1")
        self.ws_mgr = None
        self.ws_groups = {}       # grup id -> set(wl_output id)
        self.workspaces = {}      # ext_workspace_handle id -> {"id", "name", "group"}
        self.stack_path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "quickshell-previews", "stack.json")
        self.stack = self.load_stack()  # identifier -> odak sırası
        self.stack_next = max(self.stack.values(), default=0) + 1
        self.dirty = True

    # --- kurulum ----------------------------------------------------------
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
            sys.exit("ext_foreign_toplevel_list_v1 / zcosmic_toplevel_info_v1 not found (not COSMIC?)")
        if self.globals["zcosmic_toplevel_info_v1"][1] < 2:
            sys.exit("zcosmic_toplevel_info_v1 version < 2")
        # Çalışma alanı nesneleri, pencereler bildirilmeden önce bu bağlantıda var olmalı
        for name, ver in self.output_globals:
            self.bind_output(name, ver)
        self.ws_mgr = self.bind("ext_workspace_manager_v1", 1)
        self.info = self.bind("zcosmic_toplevel_info_v1", 3)
        self.mgr = self.bind("zcosmic_toplevel_manager_v1", 4)
        self.seat = self.bind("wl_seat", 1)
        self.shm = self.bind("wl_shm", 1)
        self.src_mgr = self.bind("ext_foreign_toplevel_image_capture_source_manager_v1", 1)
        self.copy_mgr = self.bind("ext_image_copy_capture_manager_v1", 1)
        self.list = self.bind("ext_foreign_toplevel_list_v1", 1)

    def load_stack(self):
        try:
            with open(self.stack_path) as f:
                data = json.load(f)
            return {k: int(v) for k, v in data.items()}
        except (OSError, ValueError, AttributeError):
            return {}

    def save_stack(self):
        # yalnızca açık pencereler; kapananların kaydı silinir
        live = {h["ident"] for h in self.handles.values() if h["ident"]}
        self.stack = {k: v for k, v in self.stack.items() if k in live}
        try:
            os.makedirs(os.path.dirname(self.stack_path), exist_ok=True)
            tmp = self.stack_path + ".tmp"
            with open(tmp, "w") as f:
                json.dump(self.stack, f)
            os.replace(tmp, self.stack_path)
        except OSError:
            pass

    def raise_handle(self, h):
        if not h["ident"]:
            return
        if self.stack.get(h["ident"]) == self.stack_next - 1:
            return  # zaten en üstte
        self.stack[h["ident"]] = self.stack_next
        self.stack_next += 1
        self.save_stack()

    def bind_output(self, name, ver):
        oid = self.wl.new_id()
        self.wl.send(self.registry, WL_REGISTRY_BIND, name, "wl_output", min(ver, 4), oid)
        self.outputs[oid] = ""

    # --- olaylar ----------------------------------------------------------
    def dispatch(self, obj, op, p):
        if obj == 1:
            if op == WL_DISPLAY_EV_ERROR:
                oid, off = get_uint(p, 0)
                code, off = get_uint(p, off)
                msg, _ = get_string(p, off)
                sys.exit(f"wayland error: object {oid} code {code}: {msg}")
            return
        if obj == self.registry:
            if op == WL_REGISTRY_EV_GLOBAL:
                name, off = get_uint(p, 0)
                iface, off = get_string(p, off)
                ver, _ = get_uint(p, off)
                self.globals.setdefault(iface, (name, ver))
                if iface == "wl_output" and self.info is not None:
                    self.bind_output(name, ver)  # sonradan takılan ekran
                elif iface == "wl_output":
                    self.output_globals.append((name, ver))
            return
        if obj == self.list:
            if op == EXT_LIST_EV_TOPLEVEL:
                hid, _ = get_uint(p, 0)
                cid = self.wl.new_id()
                self.wl.send(self.info, COSMIC_INFO_GET_COSMIC_TOPLEVEL, cid, hid)
                self.handles[hid] = {"id": hid, "cosmic": cid, "appId": "", "title": "",
                                     "activated": False, "minimized": False,
                                     "maximized": False, "fullscreen": False,
                                     "ws": set(), "geometry": None, "ident": ""}
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
            elif op == EXT_HANDLE_EV_IDENTIFIER:
                h["ident"], _ = get_string(p, 0)
                if h["activated"]:
                    self.raise_handle(h)
            elif op == EXT_HANDLE_EV_CLOSED:
                for cap in list(self.captures.values()):
                    if cap["hid"] == obj:
                        self.finish_capture(cap, False)
                self.wl.send(h["cosmic"], COSMIC_HANDLE_DESTROY)
                self.wl.send(obj, EXT_HANDLE_DESTROY)
                self.cosmic_to_ext.pop(h["cosmic"], None)
                del self.handles[obj]
            self.dirty = True
            return
        hid = self.cosmic_to_ext.get(obj)
        if hid is not None:
            if op == COSMIC_HANDLE_EV_STATE:
                arr, _ = get_array(p, 0)
                states = set(struct.unpack(f"<{len(arr) // 4}I", arr))
                h = self.handles[hid]
                if STATE_ACTIVATED in states and not h["activated"]:
                    h["activated"] = True
                    self.raise_handle(h)
                h["activated"] = STATE_ACTIVATED in states
                h["minimized"] = STATE_MINIMIZED in states
                h["maximized"] = STATE_MAXIMIZED in states
                h["fullscreen"] = STATE_FULLSCREEN in states
                self.dirty = True
            elif op == COSMIC_HANDLE_EV_GEOMETRY:
                out, x, y, w, hh = struct.unpack_from("<Iiiii", p)
                self.handles[hid]["geometry"] = {"output": out, "x": x, "y": y, "w": w, "h": hh}
                self.dirty = True
            elif op == COSMIC_HANDLE_EV_EXT_WS_ENTER:
                self.handles[hid]["ws"].add(get_uint(p, 0)[0])
                self.dirty = True
            elif op == COSMIC_HANDLE_EV_EXT_WS_LEAVE:
                self.handles[hid]["ws"].discard(get_uint(p, 0)[0])
                self.dirty = True
            return
        if obj in self.outputs:
            if op == WL_OUTPUT_EV_NAME:
                self.outputs[obj], _ = get_string(p, 0)
                self.dirty = True
            return
        if obj == self.ws_mgr:
            if op == WS_MGR_EV_GROUP:
                self.ws_groups[get_uint(p, 0)[0]] = set()
            elif op == WS_MGR_EV_WORKSPACE:
                self.workspaces[get_uint(p, 0)[0]] = {"id": "", "name": "", "group": None}
            return
        group = self.ws_groups.get(obj)
        if group is not None:
            arg = get_uint(p, 0)[0] if len(p) >= 4 else 0
            if op == WS_GROUP_EV_OUTPUT_ENTER:
                group.add(arg)
            elif op == WS_GROUP_EV_OUTPUT_LEAVE:
                group.discard(arg)
            elif op == WS_GROUP_EV_WS_ENTER and arg in self.workspaces:
                self.workspaces[arg]["group"] = obj
            elif op == WS_GROUP_EV_WS_LEAVE and arg in self.workspaces:
                if self.workspaces[arg]["group"] == obj:
                    self.workspaces[arg]["group"] = None
            elif op == WS_GROUP_EV_REMOVED:
                del self.ws_groups[obj]
                self.wl.send(obj, WS_GROUP_DESTROY)
            self.dirty = True
            return
        ws = self.workspaces.get(obj)
        if ws is not None:
            if op == WS_EV_ID:
                ws["id"], _ = get_string(p, 0)
            elif op == WS_EV_NAME:
                ws["name"], _ = get_string(p, 0)
            elif op == WS_EV_REMOVED:
                del self.workspaces[obj]
                self.wl.send(obj, WS_DESTROY)
                for h in self.handles.values():
                    h["ws"].discard(obj)
            self.dirty = True
            return
        cap = self.captures.get(obj)
        if cap is not None:
            self.capture_event(cap, obj, op, p)

    # --- önizleme yakalama ------------------------------------------------
    def start_capture(self, hid, path, max_w, max_h):
        if hid not in self.handles or not (self.shm and self.src_mgr and self.copy_mgr):
            self.emit_preview(hid, path, False)
            return
        src, session = self.wl.new_id(), self.wl.new_id()
        self.wl.send(self.src_mgr, SRC_MGR_CREATE_SOURCE, src, hid)
        self.wl.send(self.copy_mgr, COPY_MGR_CREATE_SESSION, session, src, 0)
        cap = {"hid": hid, "path": path, "max_w": max_w, "max_h": max_h,
               "src": src, "session": session, "frame": None, "pool": None,
               "buffer": None, "fd": None, "mm": None, "w": 0, "h": 0, "fmt": None, "formats": set()}
        self.captures[session] = cap

    def capture_event(self, cap, obj, op, p):
        if obj == cap["session"]:
            if op == SESSION_EV_BUFFER_SIZE:
                cap["w"], off = get_uint(p, 0)
                cap["h"], _ = get_uint(p, off)
            elif op == SESSION_EV_SHM_FORMAT:
                cap["formats"].add(get_uint(p, 0)[0])
            elif op == SESSION_EV_DONE and cap["frame"] is None:
                self.attach_and_capture(cap)
            elif op == SESSION_EV_STOPPED:
                self.finish_capture(cap, False)
        elif obj == cap["frame"]:
            if op == FRAME_EV_READY:
                try:
                    write_ppm(cap["path"], cap["mm"], cap["w"], cap["h"], SHM_FORMATS[cap["fmt"]],
                              cap["max_w"], cap["max_h"])
                    self.finish_capture(cap, True)
                except OSError:
                    self.finish_capture(cap, False)
            elif op == FRAME_EV_FAILED:
                self.finish_capture(cap, False)

    def attach_and_capture(self, cap):
        fmt = next((f for f in SHM_FORMATS if f in cap["formats"]), None)
        cap["fmt"] = fmt
        w, h = cap["w"], cap["h"]
        if fmt is None or w == 0 or h == 0:
            self.finish_capture(cap, False)
            return
        stride, size = w * 4, w * 4 * h
        fd = os.memfd_create("qs-preview", os.MFD_CLOEXEC)
        os.ftruncate(fd, size)
        cap["fd"], cap["mm"] = fd, mmap.mmap(fd, size)
        cap["pool"], cap["buffer"], cap["frame"] = self.wl.new_id(), self.wl.new_id(), self.wl.new_id()
        self.wl.send(self.shm, WL_SHM_CREATE_POOL, cap["pool"], size, fd=fd)
        self.wl.send(cap["pool"], WL_SHM_POOL_CREATE_BUFFER, cap["buffer"], 0, w, h, stride, fmt)
        self.wl.send(cap["session"], SESSION_CREATE_FRAME, cap["frame"])
        self.wl.send(cap["frame"], FRAME_ATTACH_BUFFER, cap["buffer"])
        self.wl.send(cap["frame"], FRAME_DAMAGE_BUFFER, 0, 0, w, h)
        self.wl.send(cap["frame"], FRAME_CAPTURE)
        self.captures[cap["frame"]] = cap

    def finish_capture(self, cap, ok):
        if cap["frame"] is not None:
            self.wl.send(cap["frame"], FRAME_DESTROY)
            self.captures.pop(cap["frame"], None)
        self.wl.send(cap["session"], SESSION_DESTROY)
        self.wl.send(cap["src"], SRC_DESTROY)
        self.captures.pop(cap["session"], None)
        if cap["buffer"] is not None:
            self.wl.send(cap["buffer"], WL_BUFFER_DESTROY)
            self.wl.send(cap["pool"], WL_SHM_POOL_DESTROY)
        if cap["mm"] is not None:
            cap["mm"].close()
        if cap["fd"] is not None:
            os.close(cap["fd"])
        self.emit_preview(cap["hid"], cap["path"], ok)

    # --- komutlar / çıktı -------------------------------------------------
    def command(self, line):
        parts = line.split()
        if len(parts) < 2 or not parts[1].isdigit():
            return
        hid, cmd = int(parts[1]), parts[0]
        if cmd == "capture" and len(parts) == 5:
            try:
                self.start_capture(hid, parts[2], max(1, int(parts[3])), max(1, int(parts[4])))
            except ValueError:
                pass
            return
        h = self.handles.get(hid)
        if h is None or self.mgr is None:
            return
        c = h["cosmic"]
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

    @staticmethod
    def write(obj):
        sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    def emit_preview(self, hid, path, ok):
        self.write({"type": "preview", "id": hid, "path": path, "ok": ok})

    def ws_info(self, wid):
        ws = self.workspaces[wid]
        outs = self.ws_groups.get(ws["group"], set())
        return {"id": ws["id"], "name": ws["name"], "outputs": sorted(self.outputs.get(o, "") for o in outs)}

    def emit(self):
        if not self.dirty:
            return
        self.dirty = False
        out = []
        for h in self.handles.values():
            o = {k: v for k, v in h.items() if k not in ("cosmic", "ws", "geometry", "ident")}
            o["stack"] = self.stack.get(h["ident"], 0)
            o["workspaces"] = [self.ws_info(w) for w in h["ws"] if w in self.workspaces]
            g = h["geometry"]
            o["geometry"] = None if g is None else dict(g, output=self.outputs.get(g["output"], ""))
            out.append(o)
        self.write({"type": "toplevels", "list": out})

    def run(self):
        self.roundtrip_globals()
        pending = b""
        while True:
            ready, _, _ = select.select([self.wl.sock, 0], [], [], None if not self.dirty else 0.03)
            if self.wl.sock in ready:
                for obj, op, p in self.wl.read():
                    self.dispatch(obj, op, p)
            if 0 in ready:
                chunk = os.read(0, 4096)
                if not chunk:
                    return  # Quickshell kapandı
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
