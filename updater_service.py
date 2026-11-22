import os
import re
import subprocess
import sys
import requests
from config import BASE_DIR, HOST_API, HOST_WEB, LAUNCHER_RELEASES_URL, LAUNCHER_REPO, LAUNCHER_VERSION, debug_log

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) RDL-Launcher/1.0"}


def _parse_ver_tuple(ver_str):
    nums = [int(x) for x in re.findall(r"\d+", ver_str or "")]
    return tuple(nums) if nums else (0,)


def is_newer_version(remote_ver, local_ver=LAUNCHER_VERSION):
    return _parse_ver_tuple(remote_ver) > _parse_ver_tuple(local_ver)


def check_launcher_update():
    """Devuelve (has_update, remote_ver, download_url) usando releases.atom sin límites de API."""
    remote_ver = ""
    raw_tag = ""
    download_url = LAUNCHER_RELEASES_URL

    # 1. Feed Atom de Releases (sin rate-limit de API y funciona al instante tras publicar)
    atom_url = f"https://{HOST_WEB}/{LAUNCHER_REPO}/releases.atom"
    try:
        r = requests.get(atom_url, timeout=8, headers=HEADERS)
        debug_log("UPDATER", f"Atom status: {r.status_code}")
        if r.status_code == 200:
            m = re.search(rf'/{re.escape(LAUNCHER_REPO)}/releases/tag/([^"\'<>\s]+)', r.text)
            if m:
                raw_tag = m.group(1)
                remote_ver = raw_tag.lstrip("vV")
                download_url = f"https://{HOST_WEB}/{LAUNCHER_REPO}/releases/download/{raw_tag}/RDL_Launcher.exe"
    except Exception as e:
        debug_log("UPDATER", f"Error leyendo releases.atom: {e}")

    # 2. Respaldo: API de GitHub Releases (por si el .exe tiene otro nombre)
    if not remote_ver:
        api_url = f"https://{HOST_API}/repos/{LAUNCHER_REPO}/releases"
        try:
            r = requests.get(api_url, timeout=8, headers=HEADERS)
            if r.status_code == 200 and r.json():
                latest_rel = r.json()[0]
                raw_tag = latest_rel.get("tag_name", "")
                remote_ver = raw_tag.lstrip("vV")
                for asset in latest_rel.get("assets", []):
                    if asset.get("name", "").lower().endswith(".exe"):
                        download_url = asset.get("browser_download_url", download_url)
                        break
        except Exception as e:
            debug_log("UPDATER", f"Error en API releases: {e}")

    debug_log("UPDATER", f"Versión local: {LAUNCHER_VERSION} | Remota: {remote_ver} | URL: {download_url}")
    return is_newer_version(remote_ver, LAUNCHER_VERSION), remote_ver, download_url


def download_and_apply_exe_update(download_url, progress_cb=None):
    """Descarga el nuevo .exe y lanza un script .bat desvinculado para reemplazarlo y reiniciar."""
    if not getattr(sys, "frozen", False):
        return False

    current_exe = sys.executable
    old_exe = current_exe + ".old"
    new_exe = os.path.join(BASE_DIR, "RDL_Launcher_new.exe")
    bat_path = os.path.join(BASE_DIR, "_update_launcher.bat")

    if os.path.exists(old_exe):
        try:
            os.remove(old_exe)
        except Exception:
            pass

    debug_log("UPDATER", f"Descargando actualización desde: {download_url}")
    with requests.get(download_url, stream=True, timeout=60, headers=HEADERS, allow_redirects=True) as r:
        if r.status_code == 404:
            debug_log("UPDATER", "Asset RDL_Launcher.exe no encontrado directamente (404), abriendo web.")
            return False
        r.raise_for_status()
        total = int(r.headers.get("content-length", 0))
        downloaded = 0
        with open(new_exe, "wb") as f:
            for chunk in r.iter_content(chunk_size=65536):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if progress_cb and total > 0:
                        progress_cb(int(downloaded * 100 / total))

    # Limpia _MEIPASS2, renombra el exe antiguo y arranca limpio vía explorer.exe
    bat_script = f"""@echo off
set _MEIPASS2=
timeout /t 2 /nobreak > nul
:retry
move /y "{current_exe}" "{old_exe}" > nul 2>&1
if exist "{current_exe}" (
    timeout /t 1 /nobreak > nul
    goto retry
)
move /y "{new_exe}" "{current_exe}" > nul
explorer.exe "{current_exe}"
timeout /t 3 /nobreak > nul
del /f /q "{old_exe}" > nul 2>&1
del "%~f0"
"""
    with open(bat_path, "w", encoding="utf-8") as f:
        f.write(bat_script)

    subprocess.Popen(
        ["cmd", "/c", bat_path],
        creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS,
        close_fds=True,
    )
    return True
