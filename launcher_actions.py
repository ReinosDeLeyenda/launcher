import ctypes
from ctypes import wintypes
import os
import re
import subprocess
import threading
import time
from tkinter import messagebox
import webbrowser

from addon_service import check_github_addons, download_and_install, scan_local_addons
from config import debug_log, load_accounts, load_clients
from news_service import fetch_latest_news, load_local_logo
from tray_service import TrayManager
from ui_widgets import render_news_cards
from updater_service import check_launcher_update, download_and_apply_exe_update

VK_RETURN = 0x0D
VK_SHIFT = 0x10
KEYEVENTF_KEYUP = 0x0002


def _send_password_physical(password):
    user32 = ctypes.windll.user32
    for ch in password:
        vk_scan = user32.VkKeyScanW(ord(ch))
        if vk_scan == -1:
            continue
        vk = vk_scan & 0xFF
        shift_state = (vk_scan >> 8) & 0xFF

        if shift_state & 1:
            user32.keybd_event(VK_SHIFT, 0, 0, 0)
            time.sleep(0.01)

        user32.keybd_event(vk, 0, 0, 0)
        time.sleep(0.015)
        user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)

        if shift_state & 1:
            time.sleep(0.01)
            user32.keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0)

        time.sleep(0.02)

    time.sleep(0.15)
    user32.keybd_event(VK_RETURN, 0, 0, 0)
    time.sleep(0.05)
    user32.keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0)


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
    debug_log("AUTOLOGIN", f"Config.wtf actualizado en {cfg_path} con accountName='{username}'")


def _list_wow_hwnds():
    user32 = ctypes.windll.user32
    windows = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def enum_cb(hwnd, _):
        if not user32.IsWindowVisible(hwnd):
            return True
        rect = wintypes.RECT()
        user32.GetClientRect(hwnd, ctypes.byref(rect))
        if rect.right <= 400 or rect.bottom <= 300:
            return True

        proc_id = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(proc_id))
        buf = ctypes.create_unicode_buffer(128)
        user32.GetWindowTextW(hwnd, buf, 128)
        windows.append((hwnd, proc_id.value, buf.value))
        return True

    user32.EnumWindows(enum_cb, 0)
    return windows


def _find_wow_hwnd(pid, existing_hwnds=None):
    existing = existing_hwnds or set()
    windows = _list_wow_hwnds()

    for hwnd, proc_id, _ in windows:
        if proc_id == pid:
            return hwnd

    for hwnd, _, title in windows:
        if title == "World of Warcraft" and hwnd not in existing:
            return hwnd

    return None


def _auto_type_password_worker(proc, password, existing_hwnds):
    user32 = ctypes.windll.user32
    hwnd_found = None

    for _ in range(60):
        time.sleep(0.5)
        hwnd_found = _find_wow_hwnd(proc.pid, existing_hwnds)
        if hwnd_found:
            break
        if proc.poll() is not None and not existing_hwnds:
            break

    if not hwnd_found:
        debug_log("AUTOLOGIN", f"No se encontró la ventana de WoW para PID={proc.pid}.")
        return

    time.sleep(4.5)

    user32.ShowWindow(hwnd_found, 9)
    user32.SetForegroundWindow(hwnd_found)
    time.sleep(0.3)

    if user32.GetForegroundWindow() != hwnd_found:
        user32.SetForegroundWindow(hwnd_found)
        time.sleep(0.2)

    debug_log("AUTOLOGIN", f"Enviando contraseña por VkKeyScanW a PID={proc.pid} HWND={hwnd_found}...")
    _send_password_physical(password)

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
        self.check_self_update()

    def check_self_update(self):
        def worker():
            has_upd, remote_ver, dl_url = check_launcher_update()
            if has_upd:
                self.app.after(0, lambda v=remote_ver, u=dl_url: self.app.show_launcher_update_banner(v, u))

        threading.Thread(target=worker, daemon=True).start()

    def apply_self_update(self, download_url):
        def worker():
            self.app.set_status("Descargando actualización del launcher...")
            try:
                replaced = download_and_apply_exe_update(
                    download_url,
                    progress_cb=lambda pct: self.app.set_status(f"Descargando launcher: {pct}%"),
                )
                if replaced:
                    self.app.after(0, self.quit_app)
                else:
                    webbrowser.open(download_url)
                    self.app.set_status("Abierta página de descarga en el navegador")
            except Exception as e:
                err_msg = str(e)
                self.app.set_status("Error al actualizar launcher")
                self.app.after(0, lambda m=err_msg: messagebox.showerror("Error de actualización", m))

        threading.Thread(target=worker, daemon=True).start()

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
        if hasattr(self.app, "check_wow_exe_warning"):
            self.app.check_wow_exe_warning()
        self.load_addons()

    def launch_multibox(self, plan):
        threading.Thread(target=_multibox_launch_worker, args=(self.app, plan), daemon=True).start()

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

        existing_hwnds = {hwnd for hwnd, _, _ in _list_wow_hwnds()} if has_auto else set()
        proc = subprocess.Popen([exe], cwd=self.app.wow_dir)
        if has_auto:
            self.app.set_status(f"Iniciando WoW ({active})...")
            threading.Thread(
                target=_auto_type_password_worker,
                args=(proc, pwd, existing_hwnds),
                daemon=True,
            ).start()
        else:
            self.app.set_status("World of Warcraft iniciado")


def _prepare_wow_config_multibox(wow_dir, username=None):
    wtf_dir = os.path.join(wow_dir, "WTF")
    os.makedirs(wtf_dir, exist_ok=True)
    cfg_path = os.path.join(wtf_dir, "Config.wtf")

    content = ""
    if os.path.isfile(cfg_path):
        with open(cfg_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

    settings = {
        "gxWindow": "1",
        "gxMaximize": "0",
    }
    if username:
        settings["accountName"] = username

    for key, val in settings.items():
        line = f'SET {key} "{val}"'
        pattern = rf'^SET\s+{re.escape(key)}\s+".*?"'
        if re.search(pattern, content, re.MULTILINE | re.IGNORECASE):
            content = re.sub(pattern, line, content, flags=re.MULTILINE | re.IGNORECASE)
        else:
            content = content.rstrip() + ("\n" if content.strip() else "") + line + "\n"

    with open(cfg_path, "w", encoding="utf-8") as f:
        f.write(content)


def _apply_window_rect(hwnd, rect, show_borders=False):
    user32 = ctypes.windll.user32
    x, y, w, h = rect
    GWL_STYLE = -16
    WS_CAPTION = 0x00C00000
    WS_THICKFRAME = 0x00040000
    SWP_FRAMECHANGED = 0x0020
    SWP_NOZORDER = 0x0004
    SWP_SHOWWINDOW = 0x0040

    style = user32.GetWindowLongW(hwnd, GWL_STYLE)
    if show_borders:
        style |= (WS_CAPTION | WS_THICKFRAME)
    else:
        style &= ~(WS_CAPTION | WS_THICKFRAME)
    user32.SetWindowLongW(hwnd, GWL_STYLE, style)
    user32.ShowWindow(hwnd, 9)
    user32.SetWindowPos(hwnd, 0, x, y, w, h, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_SHOWWINDOW)


def _multibox_launch_worker(app, plan):
    user32 = ctypes.windll.user32
    accounts, _ = load_accounts()
    clients, _ = load_clients()
    launched = []

    for idx, item in enumerate(plan):
        acc_alias, cli_name, rect = item[0], item[1], item[2]
        show_borders = item[3] if len(item) > 3 else False

        wow_dir = clients.get(cli_name)
        if not wow_dir:
            continue
        exe = os.path.join(wow_dir, "Wow.exe")
        if not os.path.isfile(exe):
            debug_log("MULTIBOX_ERR", f"No existe Wow.exe en {wow_dir}")
            continue

        has_auto = acc_alias != "Manual" and acc_alias in accounts
        user, pwd = accounts[acc_alias] if has_auto else (None, None)

        try:
            _prepare_wow_config_multibox(wow_dir, user)
        except Exception as e:
            debug_log("MULTIBOX_ERR", f"Error preparando Config.wtf: {e}")

        existing_hwnds = {hwnd for hwnd, _, _ in _list_wow_hwnds()}
        app.set_status(f"Multibox: iniciando ventana #{idx + 1} ({acc_alias})...")
        proc = subprocess.Popen([exe], cwd=wow_dir)

        hwnd_found = None
        for _ in range(60):
            time.sleep(0.4)
            hwnd_found = _find_wow_hwnd(proc.pid, existing_hwnds)
            if hwnd_found:
                break

        if hwnd_found:
            _apply_window_rect(hwnd_found, rect, show_borders)
            launched.append((hwnd_found, rect, show_borders, pwd))
        else:
            debug_log("MULTIBOX_ERR", f"No se detecto ventana para WoW #{idx + 1} (PID={proc.pid})")

    if not launched:
        app.set_status("Multibox: no se pudo iniciar ninguna ventana")
        return

    time.sleep(4.2)
    for hwnd, rect, show_borders, pwd in launched:
        _apply_window_rect(hwnd, rect, show_borders)
        if pwd:
            user32.SetForegroundWindow(hwnd)
            time.sleep(0.25)
            _send_password_physical(pwd)
            time.sleep(0.2)

    app.set_status(f"Multibox activo ({len(launched)} ventanas)")
