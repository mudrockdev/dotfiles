#!/usr/bin/env python3
"""Aura (mpvpaper) duvar kağıdının o anki karesini bir dosyaya çıkarır.

Kullanım: aura-frame.py <çıkış-adı> <hedef.jpg> <genişlik>

Aura çalışıyorsa ekranın mpv soketinden (ör. $XDG_RUNTIME_DIR/aura/mpv_DP-1.sock,
yoksa mpv_all.sock) oynatılan dosya ve konum okunur; video ise ffmpeg ile o anki kare
çıkarılır, resimse yolu doğrudan verilir.

Çıktı (stdout), tek satır JSON: {"path": "<dosya>"}  — Aura yoksa / hata olursa {"path": ""}
(mpv'nin kendi screenshot komutu mpvpaper'ın libmpv + hwdec çıktısında çalışmıyor.)
"""

import json
import os
import socket
import subprocess
import sys

IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".avif", ".jxl")


def mpv(sock_path, *command):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.5)
    s.connect(sock_path)
    try:
        s.sendall((json.dumps({"command": list(command), "request_id": 1}) + "\n").encode())
        data = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                raise ConnectionError("mpv closed the socket")
            data += chunk
            *lines, data = data.split(b"\n")
            for line in lines:
                msg = json.loads(line)
                if msg.get("request_id") == 1:
                    if msg.get("error") != "success":
                        raise RuntimeError(msg.get("error"))
                    return msg.get("data")
    finally:
        s.close()


def main():
    output, target, width = sys.argv[1], sys.argv[2], max(16, int(sys.argv[3]))
    run = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "aura")
    socks = [os.path.join(run, f"mpv_{output}.sock"), os.path.join(run, "mpv_all.sock")]
    for sock in socks:
        if not os.path.exists(sock):
            continue
        try:
            path = mpv(sock, "get_property", "path")
            if not path:
                continue
            if path.lower().endswith(IMAGE_EXT):
                return path
            try:
                pos = float(mpv(sock, "get_property", "time-pos") or 0)
            except (RuntimeError, TypeError, ValueError):
                pos = 0.0
        except (OSError, RuntimeError, ValueError):
            continue
        os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
        tmp = target + ".tmp.jpg"
        r = subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-y", "-ss", f"{pos:.3f}", "-i", path,
                            "-frames:v", "1", "-vf", f"scale={width}:-2", "-q:v", "4", tmp],
                           capture_output=True, timeout=10)
        if r.returncode == 0 and os.path.exists(tmp):
            os.replace(tmp, target)
            return target
    return ""


if __name__ == "__main__":
    try:
        result = main()
    except Exception:  # noqa: BLE001 — panel yalnızca boş yol görsün
        result = ""
    print(json.dumps({"path": result}))
