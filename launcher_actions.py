import ctypes
from ctypes import wintypes
import os
import re
import subprocess
import threading
import time
from tkinter import messagebox

from addon_service import check_github_addons, download_and_install, scan_local_addons
from config import debug_log, load_accounts
from news_service import fetch_latest_news, load_local_logo
from tray_service import TrayManager
from ui_widgets import render_news_cards

WM_CHAR = 0x0102
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
VK_RETURN = 0x0D


def _send_password_to_hwnd(hwnd, password):
    user32 = ctypes.windll.user32
    for ch in password:
        user32.PostMessageW(hwnd, WM_CHAR, ord(ch), 0)
        time.sleep(0.02)

    time.sleep(0.15)
    user32.PostMessageW(hwnd, WM_KEYDOWN, VK_RETURN, 0x001C0001)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_KEYUP, VK_RETURN, 0xC01C0001)


def _set_wow_account_name(wow_dir, username):
    wtf_dir = os.path.join(wow_dir, "WTF")
    os.makedirs(wtf_dir, exist_ok=True)
    cfg_path = os.path.join(wtf_dir, "Config.wtf")

    content = ""
    if os.path.isfile(cfg_path):
        with open(cfg_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

    line = f'SET accountName "{username}"'
    if re.search(r'^SET\s+accountName\s+".*?"', content, re.MULTILINE | re.IGNORECASE):
        content = re.sub(r'^SET\s+accountName\s+".*?"', line, content, flags=re.MULTILINE | re.IGNORECASE)
    else:
        content = content.rstrip() + ("\n" if content.strip() else "") + line + "\n"

    with open(cfg_path, "w", encoding="utf-8") as f:
        f.write(content)
    debug_log("AUTOLOGIN", f"Config.wtf actualizado con accountName='{username}'")


def _find_wow_hwnd(pid):
    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def enum_cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            proc_id = ctypes.c_ulong()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(proc_id))
            if proc_id.value == pid:
                rect = wintypes.RECT()
                user32.GetClientRect(hwnd, ctypes.byref(rect))
                if rect.right > 400 and rect.bottom > 300:
                    found.append(hwnd)
        return True

    user32.EnumWindows(enum_cb, 0)
    return found[0] if found else None


def _auto_type_password_worker(pid, password):
    hwnd_found = None
    for _ in range(60):
        time.sleep(0.5)
        hwnd_found = _find_wow_hwnd(pid)
        if hwnd_found:
            break

    if not hwnd_found:
        debug_log("AUTOLOGIN", "No se encontró la ventana de WoW.")
        return

    time.sleep(4.0)
    debug_log("AUTOLOGIN", f"Enviando contraseña por PostMessageW a HWND={hwnd_found}...")
    _send_password_to_hwnd(hwnd_found, password)

class LauncherController:
    def __init__(self, app):
        self.app = app
        self.tray = TrayManager(
            on_show_cb=lambda: app.after(0, self.restore_from_tray),
            on_play_cb=lambda: app.after(0, self.launch_wow),
            on_quit_cb=lambda: app.after(0, self.quit_app),
        )
        self.tray.start()

    def hide_to_tray(self):
        self.app.withdraw()

    def restore_from_tray(self):
        self.app.deiconify()
        self.app.lift()
        self.app.focus_force()

    def on_close_window(self):
        if self.app.minimize_to_tray:
            self.hide_to_tray()
        else:
            self.quit_app()

    def quit_app(self):
        self.tray.stop()
        self.app.destroy()

    def refresh_all(self):
        self.load_logo()
        self.load_news()
        self.load_addons()

    def load_logo(self):
        try:
            self.app.logo_photo = load_local_logo(max_size=(400, 300))
            self.app.logo_label.config(image=self.app.logo_photo, text="")
        except Exception as e:
            self.app.logo_label.config(text=str(e))

    def load_news(self):
        def worker():
            self.app.set_status("Descargando noticias...")
            articles = fetch_latest_news()
            self.app.after(0, lambda a=articles: render_news_cards(self.app.news_inner, a))
            self.app.set_status("Listo")

        threading.Thread(target=worker, daemon=True).start()

    def load_addons(self, force_refresh=False):
        def worker():
            self.app.after(0, self.app.start_addons_spinner)
            self.app.set_status("Comprobando addons...")
            try:
                info = check_github_addons(self.app.wow_dir, self.app.repos, force_refresh=force_refresh)
                self.app.addons_info = info
                self.app.set_status("Listo")
            except Exception as e:
                err_msg = f"Error GitHub: {e}"
                self.app.set_status(err_msg)
            finally:
                self.app.after(0, self.app.stop_addons_spinner)

        threading.Thread(target=worker, daemon=True).start()

    def start_install(self, target_names, target_repos=None):
        repos_to_use = target_repos or self.app.repos

        def worker():
            self.app.after(0, self.app.start_addons_spinner)
            self.app.set_status("Descargando e instalando addons...")
            try:
                download_and_install(self.app.wow_dir, repos_to_use, target_names)
                self.app.set_status("¡Addons actualizados!")
                self.load_addons(force_refresh=True)
            except Exception as e:
                err_msg = str(e)
                self.app.set_status("Error de instalación")
                self.app.after(0, self.app.stop_addons_spinner)
                self.app.after(0, lambda m=err_msg: messagebox.showerror("Error", m))

        threading.Thread(target=worker, daemon=True).start()

    def reload_local_and_check(self, new_dir, new_repos, new_min_tray):
        self.app.wow_dir = new_dir
        self.app.repos = new_repos
        self.app.minimize_to_tray = new_min_tray
        self.app.addons_info = scan_local_addons(new_dir)
        self.load_addons()

    def launch_wow(self):
        exe = os.path.join(self.app.wow_dir, "Wow.exe")
        if not os.path.exists(exe):
            messagebox.showwarning(
                "Wow.exe no encontrado",
                f"No se encontró Wow.exe en:\n{self.app.wow_dir}\n\nConfigura la ruta pulsando en '⚙ Ajustes'.",
            )
            self.app.open_settings_dialog()
            return

        accounts, active = load_accounts()
        has_auto = active and active in accounts
        if has_auto:
            user, pwd = accounts[active]
            try:
                _set_wow_account_name(self.app.wow_dir, user)
            except Exception as e:
                debug_log("AUTOLOGIN_ERR", f"No se pudo escribir Config.wtf: {e}")

        proc = subprocess.Popen([exe], cwd=self.app.wow_dir)
        if has_auto:
            self.app.set_status(f"Iniciando WoW ({active})...")
            threading.Thread(target=_auto_type_password_worker, args=(proc.pid, pwd), daemon=True).start()
        else:
            self.app.set_status("World of Warcraft iniciado")
