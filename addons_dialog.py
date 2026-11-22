import tkinter as tk
from config import THEME, extract_github_slug


def open_addons_window(parent, addons_info, repos_order, is_checking, on_refresh_cb, on_install_cb, register_listener):
    win = tk.Toplevel(parent)
    win.title("Gestor de Addons - Reinos de Leyenda")
    win.geometry("650x500")
    win.minsize(560, 420)
    win.configure(bg=THEME["bg_panel"])
    win.transient(parent)

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 325
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 250
    win.geometry(f"+{x}+{y}")

    top_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    top_bar.pack(fill="x", padx=10, pady=(10, 6))

    tk.Label(
        top_bar,
        text="🧩 GESTOR DE ADDONS",
        font=("Segoe UI", 10, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_card"],
        padx=10,
        pady=6,
    ).pack(side="left")

    tk.Button(
        top_bar,
        text="Actualizar todos",
        font=("Segoe UI", 8, "bold"),
        fg="#04121f",
        bg=THEME["border_bright"],
        relief="flat",
        padx=10,
        pady=3,
        cursor="hand2",
        command=lambda: on_install_cb(None, None),
    ).pack(side="right", padx=8, pady=4)

    tk.Button(
        top_bar,
        text="Comprobar",
        font=("Segoe UI", 8, "bold"),
        fg=THEME["text_main"],
        bg=THEME["bg_panel"],
        relief="flat",
        padx=10,
        pady=3,
        cursor="hand2",
        command=lambda: on_refresh_cb(True),
    ).pack(side="right", padx=4, pady=4)

    banner_frame = tk.Frame(win, bg=THEME["accent"], highlightbackground=THEME["border_bright"], highlightthickness=1)
    banner_lbl = tk.Label(
        banner_frame,
        text="⏳ Buscando Actualizaciones en GitHub...",
        font=("Segoe UI", 9, "bold"),
        fg="#04121f",
        bg=THEME["accent"],
        pady=4,
    )
    banner_lbl.pack(fill="x")

    def set_banner(checking):
        if not win.winfo_exists():
            return
        if checking:
            banner_frame.pack(fill="x", padx=10, pady=(0, 6), before=box)
        else:
            banner_frame.pack_forget()

    box = tk.Frame(win, bg=THEME["bg_panel"])
    box.pack(fill="both", expand=True, padx=10, pady=(0, 10))

    canvas = tk.Canvas(box, bg=THEME["bg_panel"], highlightthickness=0)
    sb = tk.Scrollbar(box, orient="vertical", command=canvas.yview)
    inner = tk.Frame(canvas, bg=THEME["bg_panel"])

    inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    win_id = canvas.create_window((0, 0), window=inner, anchor="nw")
    canvas.bind("<Configure>", lambda e: canvas.itemconfig(win_id, width=e.width))
    canvas.configure(yscrollcommand=sb.set)

    canvas.pack(side="left", fill="both", expand=True)
    sb.pack(side="right", fill="y")

    def on_wheel(event):
        canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    canvas.bind("<MouseWheel>", on_wheel)

    def get_priority(item):
        name, local_ver, remote_ver, repo_url, _ = item
        if repo_url == "Local":
            return (3, 999, name.lower())

        repo_idx = repos_order.index(repo_url) if repo_url in repos_order else 999
        if local_ver is not None and local_ver != remote_ver and remote_ver != "Desconocida":
            return (0, repo_idx, name.lower())
        if local_ver is None:
            return (1, repo_idx, name.lower())
        return (2, repo_idx, name.lower())

    def render_list(updated_info, still_checking=False):
        if not win.winfo_exists():
            return
        set_banner(still_checking)
        for w in inner.winfo_children():
            w.destroy()

        sorted_addons = sorted(updated_info, key=get_priority)
        for name, local_ver, remote_ver, repo_url, modules in sorted_addons:
            is_only_local = (repo_url == "Local")
            mod_tag = f" (+{len(modules) - 1} módulos)" if len(modules) > 1 else ""

            if is_only_local:
                status_txt = f"Instalado localmente (v{local_ver})"
                color = THEME["text_muted"]
                btn_txt = "Local"
                btn_bg = THEME["bg_bar"]
                border_col = THEME["border"]
            elif local_ver is not None and local_ver != remote_ver and remote_ver != "Desconocida":
                status_txt = f"Actualización disponible: v{local_ver} → v{remote_ver}"
                color = THEME["warning"]
                btn_txt = "Actualizar"
                btn_bg = THEME["warning"]
                border_col = THEME["warning"]
            elif local_ver is None:
                status_txt = f"No instalado  |  Versión disponible: v{remote_ver}"
                color = THEME["text_muted"]
                btn_txt = "Instalar"
                btn_bg = THEME["accent"]
                border_col = THEME["border"]
            else:
                status_txt = f"Actualizado (v{local_ver})"
                color = THEME["success"]
                btn_txt = "Reinstalar"
                btn_bg = THEME["bg_panel"]
                border_col = THEME["border"]

            row = tk.Frame(inner, bg=THEME["bg_card"], highlightbackground=border_col, highlightthickness=1)
            row.pack(fill="x", padx=4, pady=4)

            info_col = tk.Frame(row, bg=THEME["bg_card"])
            info_col.pack(side="left", fill="x", expand=True, padx=10, pady=6)

            title_row = tk.Frame(info_col, bg=THEME["bg_card"])
            title_row.pack(fill="x")

            l1 = tk.Label(title_row, text=name + mod_tag, font=("Segoe UI", 10, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], anchor="w")
            l1.pack(side="left")

            source_slug = "Instalado en WoW" if is_only_local else (extract_github_slug(repo_url) or repo_url)
            l_src = tk.Label(title_row, text=f"  [{source_slug}]", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"], anchor="w")
            l_src.pack(side="left", pady=(2, 0))

            l2 = tk.Label(info_col, text=status_txt, font=("Segoe UI", 8), fg=color, bg=THEME["bg_card"], anchor="w")
            l2.pack(fill="x")

            btn_fg = "#04121f" if btn_txt in ("Actualizar", "Instalar") else THEME["text_main"]
            btn = tk.Button(
                row,
                text=btn_txt,
                font=("Segoe UI", 8, "bold"),
                fg=btn_fg,
                bg=btn_bg,
                relief="flat",
                padx=14,
                pady=5,
                state="disabled" if is_only_local else "normal",
                cursor="arrow" if is_only_local else "hand2",
                command=lambda mods=modules, r=repo_url: on_install_cb(mods, [r]),
            )
            btn.pack(side="right", padx=10)

            for widget in (row, info_col, title_row, l1, l_src, l2, btn):
                widget.bind("<MouseWheel>", on_wheel)

    register_listener(render_list)
    win.protocol("WM_DELETE_WINDOW", lambda: (register_listener(None), win.destroy()))
    render_list(addons_info, is_checking)
