import os
import re
import subprocess
import sys
import requests
from config import BASE_DIR, HOST_API, HOST_WEB, LAUNCHER_LATEST_URL, LAUNCHER_RELEASES_URL, LAUNCHER_REPO, LAUNCHER_VERSION, debug_log

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) RDL-Launcher/1.0"}


def _parse_ver_tuple(ver_str):
    nums = [int(x) for x in re.findall(r"\d+", ver_str or "")]
    return tuple(nums) if nums else (0,)


def is_newer_version(remote_ver, local_ver=LAUNCHER_VERSION):
    return _parse_ver_tuple(remote_ver) > _parse_ver_tuple(local_ver)


def check_launcher_update():
    """Devuelve (has_update, remote_ver, download_url) sin depender solo de la API."""
    remote_ver = ""
    download_url = LAUNCHER_RELEASES_URL

    # 1. Consultar API de GitHub Releases (devuelve tag_name y URL directa al .exe)
    api_url = f"https://{HOST_API}/repos/{LAUNCHER_REPO}/releases/latest"
    try:
        r = requests.get(api_url, timeout=8, headers=HEADERS)
        if r.status_code == 200:
            data = r.json()
            remote_ver = data.get("tag_name", "").lstrip("vV")
            for asset in data.get("assets", []):
                if asset.get("name", "").lower().endswith(".exe"):
                    download_url = asset.get("browser_download_url", download_url)
                    break
    except Exception as e:
        debug_log("UPDATER", f"API releases no disponible ({e}), usando redirección web...")

    # 2. Respaldo por redirección HTTP (/releases/latest -> /releases/tag/0.91)
    if not remote_ver:
        try:
            r = requests.get(LAUNCHER_LATEST_URL, timeout=8, headers=HEADERS, allow_redirects=True)
            m = re.search(r"/releases/tag/[vV]?([^/?#]+)", r.url)
            if m:
                remote_ver = m.group(1)
                download_url = r.url
        except Exception as e:
            debug_log("UPDATER_ERR", f"Error comprobando actualización del launcher: {e}")
            return False, "", LAUNCHER_RELEASES_URL

    debug_log("UPDATER", f"Versión local: {LAUNCHER_VERSION} | Remota: {remote_ver}")
    return is_newer_version(remote_ver, LAUNCHER_VERSION), remote_ver, download_url


def download_and_apply_exe_update(download_url, progress_cb=None):
    """Descarga el nuevo .exe y lanza un script .bat para reemplazar el actual y reiniciar."""
    if not getattr(sys, "frozen", False) or not download_url.lower().endswith(".exe"):
        return False

    current_exe = sys.executable
    new_exe = os.path.join(BASE_DIR, "RDL_Launcher_new.exe")
    bat_path = os.path.join(BASE_DIR, "_update_launcher.bat")

    debug_log("UPDATER", f"Descargando actualización desde: {download_url}")
    with requests.get(download_url, stream=True, timeout=60, headers=HEADERS) as r:
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

    bat_script = f"""@echo off
timeout /t 2 /nobreak > nul
:retry
del /f /q "{current_exe}" > nul 2>&1
if exist "{current_exe}" (
    timeout /t 1 /nobreak > nul
    goto retry
)
move /y "{new_exe}" "{current_exe}" > nul
start "" "{current_exe}"
del "%~f0"
"""
    with open(bat_path, "w", encoding="utf-8") as f:
        f.write(bat_script)

    subprocess.Popen(["cmd", "/c", bat_path], creationflags=subprocess.CREATE_NO_WINDOW)
    return True
