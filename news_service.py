import os
import traceback
import requests
from bs4 import BeautifulSoup
from PIL import Image, ImageTk
from config import LOCAL_LOGO_FILE, NEWS_URL, WP_API_URL, debug_log

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


def load_local_logo(max_size=(380, 220)):
    debug_log("LOGO", f"Cargando logo local desde: {LOCAL_LOGO_FILE}")
    if not os.path.exists(LOCAL_LOGO_FILE):
        raise FileNotFoundError(f"No se encontró logo.png en:\n{LOCAL_LOGO_FILE}")
    img = Image.open(LOCAL_LOGO_FILE).convert("RGBA")
    img.thumbnail(max_size, Image.Resampling.LANCZOS)
    return ImageTk.PhotoImage(img)


def fetch_latest_news():
    articles = []
    debug_log("NEWS", f"Consultando API WP: {WP_API_URL}")

    try:
        r = requests.get(WP_API_URL, timeout=10, headers=HEADERS)
        debug_log("NEWS", f"WP API Status: {r.status_code}")
        if r.status_code == 200:
            for post in r.json():
                title = BeautifulSoup(post.get("title", {}).get("rendered", ""), "html.parser").get_text(strip=True)
                excerpt = BeautifulSoup(post.get("excerpt", {}).get("rendered", ""), "html.parser").get_text(" ", strip=True)
                date_str = post.get("date", "")[:10]
                link = post.get("link", NEWS_URL)
                if title:
                    articles.append((date_str, title, excerpt, link))
    except Exception:
        debug_log("NEWS_ERR", traceback.format_exc())

    if not articles:
        debug_log("NEWS", f"Probando scraping HTML en: {NEWS_URL}")
        try:
            r = requests.get(NEWS_URL, timeout=10, headers=HEADERS)
            debug_log("NEWS", f"HTML Status: {r.status_code}")
            soup = BeautifulSoup(r.text, "html.parser")
            for art in soup.find_all("article")[:8]:
                h2 = art.find(["h2", "h1"])
                if not h2:
                    continue
                title = h2.get_text(strip=True)
                a_tag = h2.find("a")
                link = a_tag["href"] if a_tag and a_tag.has_attr("href") else NEWS_URL
                time_tag = art.find("time")
                date_str = time_tag.get_text(strip=True) if time_tag else ""
                p_tag = art.find("p")
                excerpt = p_tag.get_text(" ", strip=True) if p_tag else ""
                articles.append((date_str, title, excerpt, link))
        except Exception as e:
            debug_log("NEWS_ERR", traceback.format_exc())
            articles.append(("Error", "No se pudieron cargar las noticias", str(e), NEWS_URL))

    debug_log("NEWS", f"Noticias cargadas: {len(articles)}")
    return articles
