import configparser
from datetime import datetime
import os
import re
import sys

from dpapi_crypto import decrypt_password, encrypt_password

DEBUG = True

BASE_DIR = os.path.dirname(os.path.abspath(sys.executable if getattr(sys, "frozen", False) else __file__))
LOG_FILE = os.path.join(BASE_DIR, "launcher.log")
INI_FILE = os.path.join(BASE_DIR, "rdl_launcher.ini")
CACHE_FILE = os.path.join(BASE_DIR, "addons_cache.json")
BUNDLE_DIR = getattr(sys, "_MEIPASS", BASE_DIR)
LOCAL_LOGO_FILE = os.path.join(BUNDLE_DIR, "logo.png")

DOMAIN_WEB = "reinosdeleyenda.org"
BASE_WEB = f"https://{DOMAIN_WEB}"
NEWS_URL = f"{BASE_WEB}/"
WP_API_URL = f"{BASE_WEB}/wp-json/wp/v2/posts?per_page=8"

HOST_API = "api." + "github.com"
HOST_RAW = "raw." + "githubusercontent.com"
HOST_WEB = "github.com"
DEFAULT_REPO_URL = f"https://{HOST_WEB}/ReinosDeLeyenda/addons"

LAUNCHER_VERSION = "0.95
LAUNCHER_REPO = "ReinosDeLeyenda/launcher"
LAUNCHER_RELEASES_URL = f"https://{HOST_WEB}/{LAUNCHER_REPO}/releases"
LAUNCHER_LATEST_URL = f"{LAUNCHER_RELEASES_URL}/latest"

THEME = {
    "bg_main": "#091b2e",
    "bg_panel": "#0d2640",
    "bg_card": "#113254",
    "bg_bar": "#071626",
    "border": "#4fc3f7",
    "border_bright": "#8be4ff",
    "text_title": "#9beeff",
    "text_main": "#e1f5fe",
    "text_muted": "#81d4fa",
    "accent": "#29b6f6",
    "accent_hover": "#4fc3f7",
    "success": "#69f0ae",
    "warning": "#ff9800",
}


def init_log():
    try:
        with open(LOG_FILE, "w", encoding="utf-8") as f:
            ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(f"[{ts}] [SESSION] === Nueva sesion del Launcher iniciada ===\n")
    except Exception:
        pass


def debug_log(tag, msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] [{tag}] {msg}"
    if DEBUG:
        print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


init_log()


def extract_github_slug(raw_input):
    text = raw_input.strip().rstrip("/")
    if text.endswith(".git"):
        text = text[:-4]
    m = re.match(r"^(?:https?://(?:www\.)?github\.com/)?([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$", text)
    return m.group(1) if m else None


def normalize_github_url(raw_input):
    slug = extract_github_slug(raw_input)
    return f"https://{HOST_WEB}/{slug}" if slug else None


def load_settings():
    cfg = configparser.ConfigParser()
    if not os.path.exists(INI_FILE):
        save_settings(os.getcwd(), [DEFAULT_REPO_URL], True)
        return os.getcwd(), [DEFAULT_REPO_URL], True

    cfg.read(INI_FILE, encoding="utf-8")
    wow_dir = cfg.get("General", "wow_dir", fallback=os.getcwd())
    min_tray = cfg.getboolean("General", "minimize_to_tray", fallback=True)
    raw_repos = cfg.get("Addons", "repos", fallback=DEFAULT_REPO_URL)
    repos = []
    for line in raw_repos.splitlines():
        full_url = normalize_github_url(line)
        if full_url and full_url not in repos:
            repos.append(full_url)
    if not repos:
        repos = [DEFAULT_REPO_URL]
    return wow_dir, repos, min_tray


def save_settings(wow_dir, repos, minimize_to_tray=True):
    cfg = configparser.ConfigParser()
    if os.path.exists(INI_FILE):
        cfg.read(INI_FILE, encoding="utf-8")
    if not cfg.has_section("General"):
        cfg["General"] = {}

    cfg["General"]["wow_dir"] = wow_dir
    cfg["General"]["minimize_to_tray"] = str(bool(minimize_to_tray))

    clean_repos = [normalize_github_url(r) for r in repos if normalize_github_url(r)]
    if not clean_repos:
        clean_repos = [DEFAULT_REPO_URL]
    cfg["Addons"] = {"repos": "\n".join(clean_repos)}

    try:
        with open(INI_FILE, "w", encoding="utf-8") as f:
            cfg.write(f)
        debug_log("CONFIG", f"Ajustes guardados en {INI_FILE}")
    except Exception as e:
        debug_log("CONFIG_ERR", f"Error guardando INI: {e}")


def load_accounts():
    cfg = configparser.ConfigParser()
    if not os.path.exists(INI_FILE):
        return {}, ""
    cfg.read(INI_FILE, encoding="utf-8")
    active = cfg.get("General", "active_account", fallback="")
    accounts = {}
    if cfg.has_section("Accounts"):
        for alias, raw in cfg.items("Accounts"):
            if "|" in raw:
                user, stored_pwd = raw.split("|", 1)
                try:
                    pwd = decrypt_password(stored_pwd)
                    accounts[alias] = (user, pwd)
                except Exception as e:
                    debug_log("DPAPI_ERR", f"No se pudo descifrar la cuenta '{alias}': {e}")
    return accounts, active


def save_accounts(accounts, active_alias=""):
    cfg = configparser.ConfigParser()
    if os.path.exists(INI_FILE):
        cfg.read(INI_FILE, encoding="utf-8")
    if not cfg.has_section("General"):
        cfg["General"] = {}
    cfg["General"]["active_account"] = active_alias

    cfg["Accounts"] = {}
    for alias, (user, pwd) in accounts.items():
        try:
            enc_pwd = encrypt_password(pwd)
            cfg["Accounts"][alias] = f"{user}|{enc_pwd}"
        except Exception as e:
            debug_log("DPAPI_ERR", f"Error cifrando cuenta '{alias}': {e}")

    try:
        with open(INI_FILE, "w", encoding="utf-8") as f:
            cfg.write(f)
        debug_log("ACCOUNTS", f"Cuentas cifradas con DPAPI y guardadas ({len(accounts)}). Activa: '{active_alias}'")
    except Exception as e:
        debug_log("ACCOUNTS_ERR", f"Error guardando cuentas: {e}")
