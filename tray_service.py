import os
import threading
from PIL import Image, ImageDraw
import pystray
from config import LOCAL_LOGO_FILE, debug_log


def _build_tray_icon_image():
    if os.path.exists(LOCAL_LOGO_FILE):
        try:
            img = Image.open(LOCAL_LOGO_FILE).convert("RGBA")
            img.thumbnail((64, 64), Image.Resampling.LANCZOS)
            return img
        except Exception:
            pass

    # Icono azul hielo de respaldo si no existe logo.png
    img = Image.new("RGBA", (64, 64), (9, 27, 46, 255))
    draw = ImageDraw.Draw(img)
    draw.ellipse((8, 8, 56, 56), fill=(79, 195, 247, 255), outline=(155, 238, 255, 255), width=3)
    return img


class TrayManager:
    def __init__(self, on_show_cb, on_play_cb, on_quit_cb):
        self.on_show_cb = on_show_cb
        self.on_play_cb = on_play_cb
        self.on_quit_cb = on_quit_cb
        self.icon = None

    def start(self):
        if self.icon is not None:
            return
        menu = pystray.Menu(
            pystray.MenuItem("Abrir Launcher", lambda icon, item: self.on_show_cb(), default=True),
            pystray.MenuItem("Jugar WoW", lambda icon, item: self.on_play_cb()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Salir", lambda icon, item: self.on_quit_cb()),
        )
        self.icon = pystray.Icon("RDL_Launcher", _build_tray_icon_image(), "Reinos de Leyenda Launcher", menu)
        threading.Thread(target=self.icon.run, daemon=True).start()
        debug_log("TRAY", "Icono de bandeja del sistema iniciado.")

    def stop(self):
        if self.icon is not None:
            try:
                self.icon.stop()
            except Exception:
                pass
            self.icon = None
