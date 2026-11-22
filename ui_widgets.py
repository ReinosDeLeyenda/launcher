import webbrowser
import tkinter as tk
from config import THEME


def render_news_cards(container, articles):
    for widget in container.winfo_children():
        widget.destroy()

    for date_str, title, excerpt, link in articles:
        card = tk.Frame(
            container,
            bg=THEME["bg_card"],
            highlightbackground=THEME["border"],
            highlightthickness=1,
        )
        card.pack(fill="x", padx=6, pady=4)

        top_row = tk.Frame(card, bg=THEME["bg_card"])
        top_row.pack(fill="x", padx=8, pady=(6, 2))

        lbl_title = tk.Label(
            top_row,
            text=title,
            font=("Segoe UI", 10, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_card"],
            cursor="hand2",
            anchor="w",
        )
        lbl_title.pack(side="left", fill="x", expand=True)
        lbl_title.bind("<Button-1>", lambda e, u=link: webbrowser.open(u))

        if date_str:
            tk.Label(
                top_row,
                text=date_str,
                font=("Segoe UI", 8),
                fg=THEME["text_muted"],
                bg=THEME["bg_card"],
            ).pack(side="right")

        if excerpt:
            short_text = (excerpt[:190] + "...") if len(excerpt) > 190 else excerpt
            tk.Label(
                card,
                text=short_text,
                font=("Segoe UI", 9),
                fg=THEME["text_main"],
                bg=THEME["bg_card"],
                justify="left",
                wraplength=510,
                anchor="w",
            ).pack(fill="x", padx=8, pady=(0, 6))


def _get_addon_priority(item):
    name, local_ver, remote_ver, _ = item
    if local_ver is not None and local_ver != remote_ver and remote_ver != "Desconocida":
        return (0, name.lower())
    if local_ver is None:
        return (1, name.lower())
    return (2, name.lower())


def render_addon_cards(container, addons_info, on_install_callback, canvas=None):
    for widget in container.winfo_children():
        widget.destroy()

    sorted_addons = sorted(addons_info, key=_get_addon_priority)

    def on_wheel(event):
        if canvas:
            canvas.xview_scroll(int(-1 * (event.delta / 120)), "units")

    for name, local_ver, remote_ver, repo in sorted_addons:
        if local_ver is not None and local_ver != remote_ver and remote_ver != "Desconocida":
            status_txt = f"Local: {local_ver} → Nueva: {remote_ver}"
            color = THEME["warning"]
            btn_txt = "Actualizar"
            btn_bg = THEME["warning"]
            border_col = THEME["warning"]
        elif local_ver is None:
            status_txt = f"No instalado  |  Web: {remote_ver}"
            color = THEME["text_muted"]
            btn_txt = "Instalar"
            btn_bg = THEME["accent"]
            border_col = THEME["border"]
        else:
            status_txt = f"Al día (v{local_ver})"
            color = THEME["success"]
            btn_txt = "Reinstalar"
            btn_bg = THEME["bg_panel"]
            border_col = THEME["border"]

        card = tk.Frame(
            container,
            bg=THEME["bg_card"],
            highlightbackground=border_col,
            highlightthickness=1,
            width=215,
            height=96,
        )
        card.pack(side="left", padx=5, pady=4)
        card.pack_propagate(False)

        lbl_name = tk.Label(card, text=name, font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], anchor="w")
        lbl_name.pack(fill="x", padx=8, pady=(5, 1))

        lbl_stat = tk.Label(card, text=status_txt, font=("Segoe UI", 8), fg=color, bg=THEME["bg_card"], anchor="w")
        lbl_stat.pack(fill="x", padx=8, pady=(0, 5))

        btn_fg = "#04121f" if btn_txt != "Reinstalar" else THEME["text_main"]
        btn = tk.Button(
            card,
            text=btn_txt,
            font=("Segoe UI", 8, "bold"),
            fg=btn_fg,
            bg=btn_bg,
            activebackground=THEME["border_bright"],
            relief="flat",
            cursor="hand2",
            command=lambda n=name, r=repo: on_install_callback([n], [r]),
        )
        btn.pack(fill="x", padx=8, pady=(0, 5))

        for w in (card, lbl_name, lbl_stat, btn):
            w.bind("<MouseWheel>", on_wheel)

    if canvas:
        container.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        canvas.xview_moveto(0)
