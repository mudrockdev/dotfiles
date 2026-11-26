#!/usr/bin/env python3
"""BlueZ eşleştirme ajanı (org.bluez.Agent1) — Quickshell Bluetooth menüsü için.

stdout'a satır başına bir JSON olay yazar, stdin'den komut okur:
  pair <device-path>          eşleştir (bu bağlantıdan; ajan isteklerini biz yanıtlarız)
  cancel <device-path>        süren eşleştirmeyi iptal et
  reply <id> <değer>          PIN/parola isteğine yanıt; onay için "yes"
  reject <id>                 isteği reddet
stdin kapanınca çıkar.

Olaylar:
  {"type":"request","id":N,"kind":"confirm|authorize|pin|passkey","device":path,"name":..,"passkey":"123456"}
  {"type":"display","device":path,"name":..,"code":"123456"}
  {"type":"cancel"}                         BlueZ isteği iptal etti
  {"type":"paired","device":path,"ok":bool,"error":".."}
"""

import json
import os
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS = "org.bluez"
AGENT_PATH = "/org/quickshell/BluetoothAgent"
AGENT_IFACE = "org.bluez.Agent1"


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


class Agent(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)
        self.bus = bus
        self.next_id = 1
        self.pending = {}  # id -> (ok, err, kind)

    def name(self, device):
        try:
            props = dbus.Interface(self.bus.get_object(BUS, device), "org.freedesktop.DBus.Properties")
            return str(props.Get("org.bluez.Device1", "Alias"))
        except dbus.DBusException:
            return str(device).rsplit("dev_", 1)[-1].replace("_", ":")

    def request(self, kind, device, ok, err, passkey=None):
        rid = self.next_id
        self.next_id += 1
        self.pending[rid] = (ok, err, kind)
        ev = {"type": "request", "id": rid, "kind": kind, "device": str(device), "name": self.name(device)}
        if passkey is not None:
            ev["passkey"] = "%06d" % passkey
        emit(ev)

    def answer(self, rid, value):
        entry = self.pending.pop(rid, None)
        if not entry:
            return
        ok, err, kind = entry
        if value is None:
            err(Rejected("Rejected"))
        elif kind == "pin":
            ok(dbus.String(value))
        elif kind == "passkey":
            try:
                ok(dbus.UInt32(int(value)))
            except ValueError:
                err(Rejected("Invalid passkey"))
        else:
            ok()

    def cancel_all(self):
        for ok, err, kind in self.pending.values():
            err(Canceled("Canceled"))
        self.pending.clear()

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s", async_callbacks=("ok", "err"))
    def RequestPinCode(self, device, ok, err):
        self.request("pin", device, ok, err)

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u", async_callbacks=("ok", "err"))
    def RequestPasskey(self, device, ok, err):
        self.request("passkey", device, ok, err)

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit({"type": "display", "device": str(device), "name": self.name(device), "code": str(pincode)})

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit({"type": "display", "device": str(device), "name": self.name(device), "code": "%06d" % passkey})

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="", async_callbacks=("ok", "err"))
    def RequestConfirmation(self, device, passkey, ok, err):
        self.request("confirm", device, ok, err, passkey)

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="", async_callbacks=("ok", "err"))
    def RequestAuthorization(self, device, ok, err):
        self.request("authorize", device, ok, err)

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # Eşleşmiş cihazların servis isteklerini kabul et (COSMIC gibi)
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        self.cancel_all()
        emit({"type": "cancel"})


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)
    manager = dbus.Interface(bus.get_object(BUS, "/org/bluez"), "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
    try:
        # Cihazdan gelen eşleştirme istekleri de bize gelsin
        manager.RequestDefaultAgent(AGENT_PATH)
    except dbus.DBusException:
        pass

    loop = GLib.MainLoop()

    def device(path):
        return dbus.Interface(bus.get_object(BUS, path), "org.bluez.Device1")

    def pair(path):
        def done():
            emit({"type": "paired", "device": path, "ok": True})
            try:
                props = dbus.Interface(bus.get_object(BUS, path), "org.freedesktop.DBus.Properties")
                props.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
            except dbus.DBusException:
                pass
            device(path).Connect(reply_handler=lambda: None, error_handler=lambda e: None, timeout=60)

        def fail(e):
            emit({"type": "paired", "device": path, "ok": False, "error": e.get_dbus_message() or e.get_dbus_name()})

        device(path).Pair(reply_handler=done, error_handler=fail, timeout=120)

    buf = b""

    def on_stdin(fd, cond):
        nonlocal buf
        data = os.read(fd, 4096)
        if not data:
            loop.quit()
            return False
        buf += data
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            parts = line.decode(errors="replace").strip().split(" ", 2)
            try:
                cmd = parts[0]
                if cmd == "pair":
                    pair(parts[1])
                elif cmd == "cancel":
                    device(parts[1]).CancelPairing(reply_handler=lambda: None, error_handler=lambda e: None)
                elif cmd == "reply":
                    agent.answer(int(parts[1]), parts[2] if len(parts) > 2 else "")
                elif cmd == "reject":
                    agent.answer(int(parts[1]), None)
            except (IndexError, ValueError, dbus.DBusException) as e:
                emit({"type": "error", "error": str(e)})
        return True

    GLib.io_add_watch(0, GLib.IO_IN | GLib.IO_HUP, on_stdin)
    try:
        loop.run()
    finally:
        try:
            manager.UnregisterAgent(AGENT_PATH)
        except dbus.DBusException:
            pass


if __name__ == "__main__":
    main()
