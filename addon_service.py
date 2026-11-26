from concurrent.futures import ThreadPoolExecutor
import io
import json
import os
import re
import shutil
import traceback
import zipfile
import requests
from config import CACHE_FILE, HOST_API, HOST_RAW, HOST_WEB, debug_log, extract_github_slug

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) RDL-Launcher/1.0"}


def _load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            debug_log("CACHE_ERR", f"Error leyendo caché: {e}")
    return {}


def _save_cache(cache_data):
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(cache_data, f, indent=2)
    except Exception as e:
        debug_log("CACHE_ERR", f"Error guardando caché: {e}")


def parse_toc_version(content):
    match = re.search(r"^##\s*Version:\s*(.+)$", content, re.MULTILINE | re.IGNORECASE)
    return match.group(1).strip() if match else "N/A"


def get_local_version(wow_dir, addon_name):
    addon_path = os.path.join(wow_dir, "Interface", "AddOns", addon_name)
    if not os.path.isdir(addon_path):
        return None

    toc_file = os.path.join(addon_path, f"{addon_name}.toc")
    if not os.path.exists(toc_file):
        for fname in os.listdir(addon_path):
            if fname.lower().endswith(".toc"):
                toc_file = os.path.join(addon_path, fname)
                break

    if os.path.exists(toc_file):
        try:
            with open(toc_file, "r", encoding="utf-8", errors="ignore") as f:
                return parse_toc_version(f.read())
        except Exception:
            return "?"
    return "Instalado"


def group_addon_folders(folder_names):
    folder_set = set(folder_names)
    groups = {}

    for name in sorted(folder_names, key=lambda s: (len(s), s.lower())):
        if "_" in name:
            prefix = name.split("_", 1)[0]
            if prefix in folder_set:
                groups.setdefault(prefix, []).append(name)
                continue
        groups.setdefault(name, [])
        if name not in groups[name]:
            groups[name].insert(0, name)

    return groups


def scan_local_addons(wow_dir):
    addons_dir = os.path.join(wow_dir, "Interface", "AddOns")
    if not os.path.isdir(addons_dir):
        return []

    raw_folders = [
        name for name in os.listdir(addons_dir)
        if not name.startswith("Blizzard_") and not name.startswith(".") and os.path.isdir(os.path.join(addons_dir, name))
    ]
    groups = group_addon_folders(raw_folders)

    local_list = []
    for main_name in sorted(groups.keys(), key=str.lower):
        ver = get_local_version(wow_dir, main_name)
        local_list.append((main_name, ver, "Local", "Local", groups[main_name]))
    return local_list

def _get_latest_commit_via_atom(slug, branch="main"):
    for br in (branch, "master" if branch == "main" else "main"):
        feed_url = f"https://{HOST_WEB}/{slug}/commits/{br}.atom"
        try:
            r = requests.get(feed_url, timeout=8, headers=HEADERS)
            if r.status_code == 200:
                m_sha = re.search(r"Commit/([0-9a-f]{40})", r.text)
                m_date = re.search(r"<updated>([^<]+)</updated>", r.text)
                if m_sha:
                    return m_sha.group(1), (m_date.group(1) if m_date else ""), br
        except Exception:
            pass
    return "", "", branch


def _fetch_repo_folders(slug, branch):
    api_url = f"https://{HOST_API}/repos/{slug}/contents"
    try:
        r = requests.get(api_url, timeout=10, headers=HEADERS)
        if r.status_code == 200:
            return [it["name"] for it in r.json() if it.get("type") == "dir" and not it["name"].startswith(".")]
        debug_log("GITHUB", f"[{slug}] API devolvió HTTP {r.status_code}, usando respaldo web sin límite...")
    except Exception as e:
        debug_log("GITHUB", f"[{slug}] Error API ({e}), usando respaldo web...")

    web_url = f"https://{HOST_WEB}/{slug}"
    r = requests.get(web_url, timeout=12, headers=HEADERS)
    r.raise_for_status()
    pattern = rf'href="/{re.escape(slug)}/tree/{re.escape(branch)}/([^"/]+)"'
    found = re.findall(pattern, r.text)
    if not found:
        other_br = "master" if branch == "main" else "main"
        pattern2 = rf'href="/{re.escape(slug)}/tree/{other_br}/([^"/]+)"'
        found = re.findall(pattern2, r.text)
    return sorted(set(name for name in found if not name.startswith(".")))


def _fetch_single_toc(slug, branches, main_name):
    for branch in branches:
        toc_url = f"https://{HOST_RAW}/{slug}/{branch}/{main_name}/{main_name}.toc"
        try:
            tr = requests.get(toc_url, timeout=8, headers=HEADERS)
            if tr.status_code == 200:
                return parse_toc_version(tr.text), branch
        except Exception:
            pass
    return "Desconocida", branches[0]


def check_github_addons(wow_dir, repo_urls, force_refresh=False):
    cache = _load_cache()
    cache_dirty = False
    results = []
    seen_mains = set()

    for repo_url in repo_urls:
        slug = extract_github_slug(repo_url)
        if not slug:
            continue

        cached_repo = cache.get(repo_url, {})
        pref_branch = cached_repo.get("branch", "main")
        latest_sha, latest_date, detected_branch = _get_latest_commit_via_atom(slug, pref_branch)
        debug_log("GITHUB", f"[{slug}] Último commit (Atom): {latest_sha[:7]} ({latest_date}) rama={detected_branch}")

        if not force_refresh and latest_sha and cached_repo.get("sha") == latest_sha and "addons" in cached_repo:
            debug_log("CACHE", f"[{slug}] Sin cambios. Cargando {len(cached_repo['addons'])} addons desde caché.")
            repo_entries = cached_repo["addons"]
        else:
            try:
                folders = _fetch_repo_folders(slug, detected_branch)
                groups = group_addon_folders(folders)
                branches = [detected_branch, "master" if detected_branch == "main" else "main"]

                repo_entries = []
                with ThreadPoolExecutor(max_workers=10) as pool:
                    futures = {
                        main_name: (modules, pool.submit(_fetch_single_toc, slug, branches, main_name))
                        for main_name, modules in groups.items()
                    }
                    for main_name, (modules, fut) in futures.items():
                        remote_ver, used_branch = fut.result()
                        if remote_ver != "Desconocida":
                            detected_branch = used_branch
                        repo_entries.append({"name": main_name, "remote_ver": remote_ver, "modules": modules})

                cache[repo_url] = {
                    "sha": latest_sha,
                    "date": latest_date,
                    "branch": detected_branch,
                    "addons": repo_entries,
                }
                cache_dirty = True
                debug_log("CACHE", f"[{slug}] Guardados {len(repo_entries)} addons en caché.")
            except Exception:
                debug_log("GITHUB_ERR", f"Error en {repo_url}:\n{traceback.format_exc()}")
                repo_entries = cached_repo.get("addons", [])

        for entry in repo_entries:
            main_name = entry["name"]
            if main_name in seen_mains:
                continue
            seen_mains.add(main_name)

            modules = entry["modules"]
            remote_ver = entry["remote_ver"]
            local_ver = get_local_version(wow_dir, main_name)
            if local_ver is not None and len(modules) > 1:
                if any(get_local_version(wow_dir, mod) is None for mod in modules):
                    local_ver = f"{local_ver} (incompleto)"

            results.append((main_name, local_ver, remote_ver, repo_url, modules))

    if cache_dirty:
        _save_cache(cache)

    for main_name, local_ver, remote_ver, source, modules in scan_local_addons(wow_dir):
        if main_name not in seen_mains:
            results.append((main_name, local_ver, remote_ver, source, modules))

    return results


def download_and_install(wow_dir, repo_urls, target_names=None):
    addons_dest = os.path.join(wow_dir, "Interface", "AddOns")
    if not os.path.isdir(addons_dest):
        raise FileNotFoundError(f"No existe la carpeta:\n{addons_dest}")

    cache = _load_cache()

    for repo_url in repo_urls:
        slug = extract_github_slug(repo_url)
        if not slug:
            continue
        preferred = cache.get(repo_url, {}).get("branch", "main")
        branches = [preferred, "master" if preferred == "main" else "main"]

        downloaded = False
        for branch in branches:
            zip_url = f"https://{HOST_WEB}/{slug}/archive/refs/heads/{branch}.zip"
            debug_log("INSTALL", f"Probando descarga ZIP: {zip_url}")
            r = requests.get(zip_url, timeout=30, headers=HEADERS)
            if r.status_code == 200:
                downloaded = True
                break

        if not downloaded:
            debug_log("INSTALL_ERR", f"No se pudo descargar ZIP de {repo_url}")
            continue

        temp_dir = os.path.join(wow_dir, "_rdl_temp_addons")
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)

        with zipfile.ZipFile(io.BytesIO(r.content)) as zf:
            zf.extractall(temp_dir)

        root_extracted = os.path.join(temp_dir, os.listdir(temp_dir)[0])
        for item in os.listdir(root_extracted):
            src = os.path.join(root_extracted, item)
            if not os.path.isdir(src):
                continue
            if target_names and item not in target_names:
                continue

            dst = os.path.join(addons_dest, item)
            debug_log("INSTALL", f"Instalando {item} desde {repo_url} -> {dst}")
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)

        shutil.rmtree(temp_dir)


def has_obsolete_modern_character_ui(wow_dir):
    addons_dir = os.path.join(wow_dir, "Interface", "AddOns")
    if not os.path.isdir(addons_dir):
        return False
    try:
        return any(name.lower() == "moderncharacterui" for name in os.listdir(addons_dir))
    except OSError:
        return False


def remove_addon_folders(wow_dir, folder_names):
    addons_dir = os.path.join(wow_dir, "Interface", "AddOns")
    if not os.path.isdir(addons_dir):
        return
    targets = {name.lower() for name in folder_names}
    for entry in os.listdir(addons_dir):
        if entry.lower() in targets:
            full_path = os.path.join(addons_dir, entry)
            if os.path.isdir(full_path):
                shutil.rmtree(full_path)
                debug_log("ADDONS", f"Addon eliminado: {full_path}")
