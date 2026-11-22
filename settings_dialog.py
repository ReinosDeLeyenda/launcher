import os
import shutil
import tkinter as tk
from tkinter import filedialog, messagebox
from config import THEME, debug_log, normalize_github_url, save_settings
from accounts_dialog import open_accounts_window

def find_realmlist_file(wow_dir):
    data_dir = os.path.join(wow_dir, "Data")
    if os.path.isdir(data_dir):
        for loc in os.listdir(data_dir):
            candidate = os.path.join(data_dir, loc, "realmlist.wtf")
            if os.path.isfile(candidate):
                return candidate
    return os.path.join(data_dir, "esES", "realmlist.wtf")

def open_settings_window(parent, current_dir, current_repos, current_min_tray, on_saved_callback, on_accounts_changed_cb):
    win = tk.Toplevel(parent)
    win.title("Ajustes - Reinos de Leyenda")
    win.geometry("560x490")
    win.resizable(False, False)
    win.configure(bg=THEME["bg_panel"])
    win.transient(parent)
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 280
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 245
    win.geometry(f"+{x}+{y}")

    # 1. CARPETA DE WOW
    tk.Label(
        win,
        text="⚙ CARPETA DE WORLD OF WARCRAFT (3.3.5a)",
        font=("Segoe UI", 9, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_panel"],
    ).pack(anchor="w", padx=16, pady=(12, 4))

    dir_row = tk.Frame(win, bg=THEME["bg_panel"])
    dir_row.pack(fill="x", padx=16)

    path_var = tk.StringVar(value=current_dir)
    tk.Entry(
        dir_row,
        textvariable=path_var,
        font=("Segoe UI", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_bar"],
        insertbackground=THEME["text_main"],
        relief="flat",
    ).pack(side="left", fill="x", expand=True, ipady=4)

    def pick_dir():
        folder = filedialog.askdirectory(parent=win, title="Selecciona la carpeta de World of Warcraft")
        if folder:
            path_var.set(folder)
            load_realm_text()

    tk.Button(
        dir_row,
        text="Examinar...",
        font=("Segoe UI", 8, "bold"),
        fg="#04121f",
        bg=THEME["accent"],
        relief="flat",
        padx=10,
        pady=4,
        cursor="hand2",
        command=pick_dir,
    ).pack(side="right", padx=(8, 0))

    # 2. HERRAMIENTAS RAPIDAS: LIMPIAR CACHE
    tools_row = tk.Frame(win, bg=THEME["bg_panel"])
    tools_row.pack(fill="x", padx=16, pady=(12, 4))

    def clear_cache():
        cache_dir = os.path.join(path_var.get().strip(), "Cache")
        if not os.path.isdir(cache_dir):
            messagebox.showinfo("Caché", "La carpeta Cache ya está vacía o no existe.", parent=win)
            return
        try:
            shutil.rmtree(cache_dir)
            debug_log("TOOLS", f"Carpeta Cache eliminada: {cache_dir}")
            messagebox.showinfo("Caché limpiada", "La carpeta Cache se ha eliminado correctamente.", parent=win)
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo borrar Cache:\n{e}", parent=win)

    tk.Button(
        tools_row,
        text="🧹 Limpiar carpeta Cache",
        font=("Segoe UI", 8, "bold"),
        fg="#04121f",
        bg=THEME["warning"],
        relief="flat",
        padx=10,
        pady=4,
        cursor="hand2",
        command=clear_cache,
    ).pack(side="left")

    tk.Button(
        tools_row,
        text="👤 Gestionar cuentas",
        font=("Segoe UI", 8, "bold"),
        fg="#04121f",
        bg=THEME["accent"],
        relief="flat",
        padx=10,
        pady=4,
        cursor="hand2",
        command=lambda: open_accounts_window(win, on_accounts_changed_cb),
    ).pack(side="left", padx=(8, 0))

    # 3. EDITOR DE REALMLIST.WTF
    tk.Label(
        win,
        text="🌐 ARCHIVO REALMLIST.WTF",
        font=("Segoe UI", 9, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_panel"],
    ).pack(anchor="w", padx=16, pady=(10, 4))

    realm_row = tk.Frame(win, bg=THEME["bg_panel"])
    realm_row.pack(fill="x", padx=16)

    realm_var = tk.StringVar()
    tk.Entry(
        realm_row,
        textvariable=realm_var,
        font=("Segoe UI", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_bar"],
        insertbackground=THEME["text_main"],
        relief="flat",
    ).pack(side="left", fill="x", expand=True, ipady=4)

    def load_realm_text():
        rfile = find_realmlist_file(path_var.get().strip())
        if os.path.isfile(rfile):
            with open(rfile, "r", encoding="utf-8", errors="ignore") as f:
                realm_var.set(f.read().strip())
        else:
            realm_var.set("set realmlist wow.reinosdeleyenda.org")

    def save_realm_text():
        rfile = find_realmlist_file(path_var.get().strip())
        os.makedirs(os.path.dirname(rfile), exist_ok=True)
        with open(rfile, "w", encoding="utf-8") as f:
            f.write(realm_var.get().strip() + "\n")
        debug_log("TOOLS", f"realmlist.wtf guardado en {rfile}")
        messagebox.showinfo("Realmlist", f"Guardado en:\n{rfile}", parent=win)

    tk.Button(
        realm_row,
        text="Guardar Realmlist",
        font=("Segoe UI", 8, "bold"),
        fg="#04121f",
        bg=THEME["accent"],
        relief="flat",
        padx=10,
        pady=4,
        cursor="hand2",
        command=save_realm_text,
    ).pack(side="right", padx=(6, 0))

    tk.Button(
        realm_row,
        text="Restaurar RdL",
        font=("Segoe UI", 8, "bold"),
        fg=THEME["text_main"],
        bg=THEME["bg_card"],
        relief="flat",
        padx=8,
        pady=4,
        cursor="hand2",
        command=lambda: realm_var.set("set realmlist wow.reinosdeleyenda.org"),
    ).pack(side="right", padx=(6, 0))

    load_realm_text()

    # 4. LISTA DE REPOSITORIOS DE GITHUB PARA ADDONS (.INI)
    tk.Label(
        win,
        text="🧩 REPOSITORIOS DE ADDONS (SOLO GITHUB — UNO POR LÍNEA)",
        font=("Segoe UI", 9, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_panel"],
    ).pack(anchor="w", padx=16, pady=(12, 4))

    repos_box = tk.Text(
        win,
        height=5,
        font=("Consolas", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_bar"],
        insertbackground=THEME["text_main"],
        relief="flat",
        padx=6,
        pady=6,
    )
    repos_box.pack(fill="x", padx=16)
    repos_box.insert("1.0", "\n".join(current_repos))

    # 5. OPCION SYSTEM TRAY
    tray_var = tk.BooleanVar(value=current_min_tray)
    tk.Checkbutton(
        win,
        text="Minimizar a la bandeja del sistema (Tray) al pulsar cerrar (X)",
        variable=tray_var,
        font=("Segoe UI", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_panel"],
        selectcolor=THEME["bg_bar"],
        activebackground=THEME["bg_panel"],
        activeforeground=THEME["text_title"],
        cursor="hand2",
    ).pack(anchor="w", padx=16, pady=(10, 0))

    # BOTONES FINALES
    btn_row = tk.Frame(win, bg=THEME["bg_panel"])
    btn_row.pack(fill="x", padx=16, pady=(14, 12))

    def save_all():
        new_dir = path_var.get().strip()
        raw_lines = repos_box.get("1.0", "end").splitlines()
        valid_repos = []
        for line in raw_lines:
            if not line.strip():
                continue
            full_url = normalize_github_url(line)
            if not full_url:
                messagebox.showwarning(
                    "URL no válida",
                    f"Solo se permiten URLs de GitHub:\n'{line}'\n\nEjemplo válido:\nhttps://github.com",
                    parent=win,
                )
                return
            if full_url not in valid_repos:
                valid_repos.append(full_url)

        save_settings(new_dir, valid_repos, tray_var.get())
        on_saved_callback(new_dir, valid_repos, tray_var.get())
        win.destroy()

    tk.Button(
        btn_row,
        text="Guardar cambios",
        font=("Segoe UI", 9, "bold"),
        fg="#04121f",
        bg=THEME["border_bright"],
        relief="flat",
        padx=16,
        pady=5,
        cursor="hand2",
        command=save_all,
    ).pack(side="right", padx=(6, 0))

    tk.Button(
        btn_row,
        text="Cancelar",
        font=("Segoe UI", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_card"],
        relief="flat",
        padx=12,
        pady=5,
        cursor="hand2",
        command=win.destroy,
    ).pack(side="right")
