import ctypes
from ctypes import wintypes
import tkinter as tk
from tkinter import messagebox, ttk
from config import THEME, load_accounts, load_clients, load_multibox_profiles, save_multibox_profiles


def get_work_area():
    rect = wintypes.RECT()
    if ctypes.windll.user32.SystemParametersInfoW(0x0030, 0, ctypes.byref(rect), 0):
        return rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top
    return 0, 0, 1920, 1080


def compute_grid_rects(rows, cols, area_x, area_y, area_w, area_h):
    rects = []
    cell_w = area_w // cols
    cell_h = area_h // rows
    for r in range(rows):
        y = area_y + r * cell_h
        h = (area_h - r * cell_h) if r == rows - 1 else cell_h
        for c in range(cols):
            x = area_x + c * cell_w
            w = (area_w - c * cell_w) if c == cols - 1 else cell_w
            rects.append((x, y, w, h))
    return rects


def open_multibox_window(parent, on_launch_multibox_cb):
    win = tk.Toplevel(parent)
    win.title("Multiboxing - Reinos de Leyenda")
    win.geometry("760x680")
    win.minsize(740, 650)
    win.resizable(True, True)
    win.configure(bg=THEME["bg_panel"])
    win.transient(parent)
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 370
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 335
    win.geometry(f"+{x}+{y}")

    accounts, _ = load_accounts()
    clients, active_client = load_clients()
    profiles = load_multibox_profiles()

    acc_options = ["Manual"] + sorted(accounts.keys())
    cli_options = list(clients.keys())
    area_x, area_y, area_w, area_h = get_work_area()

    prof_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    prof_bar.pack(fill="x", padx=14, pady=(10, 6))
    tk.Label(prof_bar, text="Perfil:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 6), pady=7)

    prof_var = tk.StringVar()
    prof_combo = ttk.Combobox(prof_bar, textvariable=prof_var, values=sorted(profiles.keys()), state="readonly", width=22)
    prof_combo.pack(side="left", padx=4, pady=7)

    prof_name_var = tk.StringVar()
    tk.Entry(prof_bar, textvariable=prof_name_var, width=22, font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").pack(side="left", padx=(10, 4), pady=7, ipady=3)

    rows_var = tk.IntVar(value=1)
    cols_var = tk.IntVar(value=2)
    borders_var = tk.BooleanVar(value=False)

    slot_vars = []
    for i in range(16):
        default_acc = acc_options[i + 1] if (i + 1) < len(acc_options) else "Manual"
        slot_vars.append((tk.StringVar(value=default_acc), tk.StringVar(value=active_client)))

    grid_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    grid_bar.pack(fill="x", padx=14, pady=(0, 6))

    tk.Label(grid_bar, text="Columnas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 4), pady=6)
    cb_cols = ttk.Combobox(grid_bar, textvariable=cols_var, values=[1, 2, 3, 4], state="readonly", width=4)
    cb_cols.pack(side="left", padx=(0, 12))

    tk.Label(grid_bar, text="Filas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(4, 4))
    cb_rows = ttk.Combobox(grid_bar, textvariable=rows_var, values=[1, 2, 3, 4], state="readonly", width=4)
    cb_rows.pack(side="left", padx=(0, 14))

    total_lbl = tk.Label(grid_bar, text="Total: 2 WoWs", font=("Segoe UI", 9, "bold"), fg=THEME["accent"], bg=THEME["bg_card"])
    total_lbl.pack(side="left", padx=6)

    tk.Checkbutton(grid_bar, text="Mostrar bordes", variable=borders_var, font=("Segoe UI", 9, "bold"), fg=THEME["text_main"], bg=THEME["bg_card"], selectcolor=THEME["bg_bar"], activebackground=THEME["bg_card"], activeforeground=THEME["text_title"], cursor="hand2", command=lambda: draw_preview()).pack(side="right", padx=10)
    preview_box = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
    preview_box.pack(fill="x", padx=14, pady=2)
    tk.Label(preview_box, text=f"VISTA PREVIA ({area_w}x{area_h} px — MAXIMO 16 WOWS)", font=("Segoe UI", 8, "bold"), fg=THEME["text_muted"], bg=THEME["bg_bar"]).pack(pady=(5, 2))

    preview_canvas = tk.Canvas(preview_box, height=205, bg="#040e18", highlightthickness=0)
    preview_canvas.pack(fill="x", padx=12, pady=(2, 8))

    slots_outer = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
    slots_outer.pack(fill="both", expand=True, padx=14, pady=(6, 4))

    slots_canvas = tk.Canvas(slots_outer, bg=THEME["bg_panel"], highlightthickness=0)
    slots_sb = ttk.Scrollbar(slots_outer, orient="vertical", command=slots_canvas.yview)
    slots_inner = tk.Frame(slots_canvas, bg=THEME["bg_panel"])

    slots_inner.bind("<Configure>", lambda _e: slots_canvas.configure(scrollregion=slots_canvas.bbox("all")))
    win_id = slots_canvas.create_window((0, 0), window=slots_inner, anchor="nw")
    slots_canvas.bind("<Configure>", lambda e: slots_canvas.itemconfig(win_id, width=e.width))
    slots_canvas.configure(yscrollcommand=slots_sb.set)
    slots_canvas.pack(side="left", fill="both", expand=True)
    slots_sb.pack(side="right", fill="y")

    def on_wheel(event):
        slots_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
    slots_canvas.bind("<MouseWheel>", on_wheel)

    slot_rows = []
    for idx in range(16):
        row = tk.Frame(slots_inner, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
        l_num = tk.Label(row, text=f"#{idx + 1}", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], width=4, anchor="w")
        l_num.pack(side="left", padx=(10, 4), pady=5)
        l_acc = tk.Label(row, text="Cuenta:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"])
        l_acc.pack(side="left", padx=(4, 4))
        cb_acc = ttk.Combobox(row, textvariable=slot_vars[idx][0], values=acc_options, state="readonly", width=20)
        cb_acc.pack(side="left", padx=4)
        cb_acc.bind("<<ComboboxSelected>>", lambda _e: draw_preview())
        l_cli = tk.Label(row, text="Cliente:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"])
        l_cli.pack(side="left", padx=(12, 4))
        cb_cli = ttk.Combobox(row, textvariable=slot_vars[idx][1], values=cli_options, state="readonly", width=26)
        cb_cli.pack(side="left", padx=4)
        cb_cli.bind("<<ComboboxSelected>>", lambda _e: draw_preview())
        for w in (row, l_num, l_acc, l_cli):
            w.bind("<MouseWheel>", on_wheel)
        slot_rows.append(row)

    def draw_preview(_event=None):
        preview_canvas.delete("all")
        cw = max(preview_canvas.winfo_width(), 300)
        ch = max(preview_canvas.winfo_height(), 140)
        rows, cols, show_borders = int(rows_var.get()), int(cols_var.get()), borders_var.get()
        rects = compute_grid_rects(rows, cols, area_x, area_y, area_w, area_h)
        pad = 6
        avail_w, avail_h = cw - pad * 2, ch - pad * 2
        scale = min(avail_w / area_w, avail_h / area_h)
        inner_w = int(area_w * scale)
        inner_h = int(area_h * scale)
        off_x = pad + (avail_w - inner_w) // 2
        off_y = pad + (avail_h - inner_h) // 2
        preview_canvas.create_rectangle(off_x - 2, off_y - 2, off_x + inner_w + 2, off_y + inner_h + 2, outline=THEME["border"], width=1)
        for idx, (rx, ry, rw, rh) in enumerate(rects):
            x1 = off_x + int(((rx - area_x) / area_w) * inner_w) + 2
            y1 = off_y + int(((ry - area_y) / area_h) * inner_h) + 2
            x2 = off_x + int(((rx - area_x + rw) / area_w) * inner_w) - 2
            y2 = off_y + int(((ry - area_y + rh) / area_h) * inner_h) - 2
            acc_name, cli_name = slot_vars[idx][0].get(), slot_vars[idx][1].get()
            preview_canvas.create_rectangle(x1, y1, x2, y2, fill=THEME["bg_card"], outline=THEME["border_bright"], width=1)
            if show_borders:
                bar_h = min(14, max(8, (y2 - y1) // 4))
                preview_canvas.create_rectangle(x1, y1, x2, y1 + bar_h, fill=THEME["accent"], outline="")
                preview_canvas.create_text((x1 + x2) // 2, y1 + bar_h // 2, text=f"#{idx + 1} ({rw}x{rh})", fill="#04121f", font=("Segoe UI", 7, "bold"))
                body_y = (y1 + y2 + bar_h) // 2
            else:
                body_y = (y1 + y2) // 2
            lbl = f"#{idx + 1} {acc_name}" if rows >= 3 else f"#{idx + 1} {acc_name}\n[{cli_name}] ({rw}x{rh})"
            preview_canvas.create_text((x1 + x2) // 2, body_y, text=lbl, fill=THEME["text_main"], font=("Segoe UI", 7 if rows >= 3 else 8, "bold"), justify="center")

    def refresh_ui(_event=None):
        rows, cols = int(rows_var.get()), int(cols_var.get())
        cnt = rows * cols
        total_lbl.config(text=f"Total: {cnt} WoW{'s' if cnt > 1 else ''}")
        for idx, row in enumerate(slot_rows):
            row.pack(fill="x", padx=6, pady=3) if idx < cnt else row.pack_forget()
        slots_canvas.yview_moveto(0)
        draw_preview()

    cb_cols.bind("<<ComboboxSelected>>", refresh_ui)
    cb_rows.bind("<<ComboboxSelected>>", refresh_ui)
    preview_canvas.bind("<Configure>", draw_preview)

    def load_selected_profile(_event=None):
        pname = prof_var.get()
        if pname not in profiles:
            return
        pdata = profiles[pname]
        rows_var.set(pdata["rows"])
        cols_var.set(pdata["cols"])
        borders_var.set(pdata["borders"])
        prof_name_var.set(pname)
        for idx, (acc, cli) in enumerate(pdata["slots"][:16]):
            slot_vars[idx][0].set(acc if acc in acc_options else "Manual")
            slot_vars[idx][1].set(cli if cli in cli_options else active_client)
        refresh_ui()

    def save_current_profile():
        pname = prof_name_var.get().strip() or prof_var.get().strip()
        if not pname:
            messagebox.showwarning("Nombre requerido", "Escribe un nombre para el perfil.", parent=win)
            return
        rows, cols = int(rows_var.get()), int(cols_var.get())
        profiles[pname] = {"rows": rows, "cols": cols, "borders": borders_var.get(), "slots": [(slot_vars[i][0].get(), slot_vars[i][1].get()) for i in range(rows * cols)]}
        save_multibox_profiles(profiles)
        prof_combo.configure(values=sorted(profiles.keys()))
        prof_var.set(pname)
        messagebox.showinfo("Guardado", f"Perfil '{pname}' guardado.", parent=win)

    def delete_current_profile():
        pname = prof_var.get().strip()
        if pname in profiles:
            profiles.pop(pname, None)
            save_multibox_profiles(profiles)
            prof_combo.configure(values=sorted(profiles.keys()))
            prof_var.set("")
            prof_name_var.set("")

    prof_combo.bind("<<ComboboxSelected>>", load_selected_profile)
    tk.Button(prof_bar, text="Guardar", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["accent"], relief="flat", padx=8, pady=3, cursor="hand2", command=save_current_profile).pack(side="left", padx=4)
    tk.Button(prof_bar, text="Borrar", font=("Segoe UI", 8, "bold"), fg="#ff8a80", bg="#3b1818", relief="flat", padx=8, pady=3, cursor="hand2", command=delete_current_profile).pack(side="left", padx=4)

    if profiles:
        prof_var.set(sorted(profiles.keys())[0])
        load_selected_profile()
    else:
        refresh_ui()

    def start_multibox():
        rows, cols, show_borders = int(rows_var.get()), int(cols_var.get()), borders_var.get()
        rects = compute_grid_rects(rows, cols, area_x, area_y, area_w, area_h)
        plan, used = [], set()
        for idx in range(rows * cols):
            acc, cli = slot_vars[idx][0].get(), slot_vars[idx][1].get()
            if acc != "Manual":
                if acc in used:
                    messagebox.showwarning("Cuenta duplicada", f"La cuenta '{acc}' esta repetida.", parent=win)
                    return
                used.add(acc)
            plan.append((acc, cli, rects[idx], show_borders))
        win.destroy()
        on_launch_multibox_cb(plan)

    bottom_bar = tk.Frame(win, bg=THEME["bg_panel"])
    bottom_bar.pack(fill="x", padx=14, pady=(6, 10))
    tk.Button(bottom_bar, text="LANZAR MULTIBOXING", font=("Segoe UI", 10, "bold"), fg="#04121f", bg=THEME["border_bright"], relief="flat", padx=18, pady=6, cursor="hand2", command=start_multibox).pack(side="right", padx=(6, 0))
    tk.Button(bottom_bar, text="Cancelar", font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_card"], relief="flat", padx=14, pady=6, cursor="hand2", command=win.destroy).pack(side="right")