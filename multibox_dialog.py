import ctypes
from ctypes import wintypes
import tkinter as tk
from tkinter import messagebox, ttk
from config import THEME, load_accounts, load_clients, load_multibox_profiles, save_multibox_profiles

PRESAVED_LAYOUTS = [
    "Cuadricula (Filas x Columnas)",
    "Prioridad 1 arriba - 2 abajo",
    "Prioridad 2 arriba, 3 abajo",
    "Prioridad centro arriba",
    "Prioridad centro",
]


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


def compute_layout_rects(layout_name, rows, cols, area_x, area_y, area_w, area_h):
    if layout_name == "Prioridad 1 arriba - 2 abajo":
        top_h = int(area_h * 0.66)
        bot_h = area_h - top_h
        w1 = area_w // 2
        return [
            (area_x, area_y, area_w, top_h),
            (area_x, area_y + top_h, w1, bot_h),
            (area_x + w1, area_y + top_h, area_w - w1, bot_h),
        ]

    if layout_name == "Prioridad 2 arriba, 3 abajo":
        top_h = int(area_h * 0.66)
        bot_h = area_h - top_h
        tw = area_w // 2
        bw = area_w // 3
        return [
            (area_x, area_y, tw, top_h),
            (area_x + tw, area_y, area_w - tw, top_h),
            (area_x, area_y + top_h, bw, bot_h),
            (area_x + bw, area_y + top_h, bw, bot_h),
            (area_x + bw * 2, area_y + top_h, area_w - bw * 2, bot_h),
        ]

    if layout_name == "Prioridad centro arriba":
        top_h = int(area_h * 0.66)
        bot_h = area_h - top_h
        side_w = int(area_w * 0.25)
        mid_w = area_w - side_w * 2
        half_top = top_h // 2
        rects = [
            (area_x + side_w, area_y, mid_w, top_h),
            (area_x, area_y, side_w, half_top),
            (area_x, area_y + half_top, side_w, top_h - half_top),
            (area_x + side_w + mid_w, area_y, side_w, half_top),
            (area_x + side_w + mid_w, area_y + half_top, side_w, top_h - half_top),
        ]
        bot_w = area_w // 6
        for i in range(6):
            bx = area_x + i * bot_w
            bw = (area_w - i * bot_w) if i == 5 else bot_w
            rects.append((bx, area_y + top_h, bw, bot_h))
        return rects

    if layout_name == "Prioridad centro":
        cw = area_w // 4
        ch = area_h // 4
        rects = [(area_x + cw, area_y + ch, cw * 2, ch * 2)]
        for r in range(4):
            y = area_y + r * ch
            h = (area_h - r * ch) if r == 3 else ch
            for c in range(4):
                if r in (1, 2) and c in (1, 2):
                    continue
                x = area_x + c * cw
                w = (area_w - c * cw) if c == 3 else cw
                rects.append((x, y, w, h))
        return rects

    return compute_grid_rects(rows, cols, area_x, area_y, area_w, area_h)

def open_multibox_window(parent, on_launch_multibox_cb):
    win = tk.Toplevel(parent)
    win.title("Multiboxing - Reinos de Leyenda")
    win.geometry("760x680")
    win.minsize(740, 650)
    win.resizable(True, True)
    win.configure(bg=THEME["bg_panel"])
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 380
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 340
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

    layout_var = tk.StringVar(value=PRESAVED_LAYOUTS[0])
    rows_var = tk.IntVar(value=1)
    cols_var = tk.IntVar(value=2)
    borders_var = tk.BooleanVar(value=False)

    slot_vars = []
    for i in range(24):
        default_acc = acc_options[i + 1] if (i + 1) < len(acc_options) else "Manual"
        slot_vars.append((tk.StringVar(value=default_acc), tk.StringVar(value=active_client)))

    grid_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    grid_bar.pack(fill="x", padx=14, pady=(0, 6))

    tk.Label(grid_bar, text="Pre-saved:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 4), pady=6)
    cb_layout = ttk.Combobox(grid_bar, textvariable=layout_var, values=PRESAVED_LAYOUTS, state="readonly", width=28)
    cb_layout.pack(side="left", padx=(0, 12))

    tk.Label(grid_bar, text="Columnas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(2, 4), pady=6)
    cb_cols = ttk.Combobox(grid_bar, textvariable=cols_var, values=[1, 2, 3, 4, 5, 6], state="readonly", width=3)
    cb_cols.pack(side="left", padx=(0, 10))

    tk.Label(grid_bar, text="Filas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(2, 4))
    cb_rows = ttk.Combobox(grid_bar, textvariable=rows_var, values=[1, 2, 3, 4], state="readonly", width=3)
    cb_rows.pack(side="left", padx=(0, 12))

    total_lbl = tk.Label(grid_bar, text="Total: 2 WoWs", font=("Segoe UI", 9, "bold"), fg=THEME["accent"], bg=THEME["bg_card"])
    total_lbl.pack(side="left", padx=6)

    tk.Checkbutton(grid_bar, text="Mostrar bordes", variable=borders_var, font=("Segoe UI", 9, "bold"), fg=THEME["text_main"], bg=THEME["bg_card"], selectcolor=THEME["bg_bar"], activebackground=THEME["bg_card"], activeforeground=THEME["text_title"], cursor="hand2", command=lambda: draw_preview()).pack(side="right", padx=10)

    bottom_bar = tk.Frame(win, bg=THEME["bg_panel"])
    bottom_bar.pack(side="bottom", fill="x", padx=14, pady=(4, 10))
    tk.Button(bottom_bar, text="LANZAR MULTIBOXING", font=("Segoe UI", 10, "bold"), fg="#04121f", bg=THEME["border_bright"], relief="flat", padx=18, pady=6, cursor="hand2", command=lambda: start_multibox()).pack(side="right", padx=(6, 0))
    tk.Button(bottom_bar, text="Cancelar", font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_card"], relief="flat", padx=14, pady=6, cursor="hand2", command=win.destroy).pack(side="right")

    slots_outer = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
    slots_outer.pack(side="bottom", fill="x", expand=False, padx=14, pady=(4, 4))

    slots_canvas = tk.Canvas(slots_outer, height=48, bg=THEME["bg_panel"], highlightthickness=0)
    slots_sb = ttk.Scrollbar(slots_outer, orient="vertical", command=slots_canvas.yview)
    slots_inner = tk.Frame(slots_canvas, bg=THEME["bg_panel"])

    slots_inner.bind("<Configure>", lambda _e: slots_canvas.configure(scrollregion=slots_canvas.bbox("all")))
    win_id = slots_canvas.create_window((0, 0), window=slots_inner, anchor="nw")
    slots_canvas.configure(yscrollcommand=slots_sb.set)
    slots_canvas.pack(side="left", fill="both", expand=True)
    slots_sb.pack(side="right", fill="y")

    def on_wheel(event):
        slots_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
    slots_canvas.bind("<MouseWheel>", on_wheel)

    slot_rows = []
    for idx in range(24):
        row = tk.Frame(slots_inner, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
        l_num = tk.Label(row, text=f"#{idx + 1}", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], width=4, anchor="w")
        l_num.pack(side="left", padx=(10, 4), pady=5)
        l_acc = tk.Label(row, text="Cuenta:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"])
        l_acc.pack(side="left", padx=(4, 4))
        cb_acc = ttk.Combobox(row, textvariable=slot_vars[idx][0], values=acc_options, state="readonly", width=18)
        cb_acc.pack(side="left", padx=4)
        cb_acc.bind("<<ComboboxSelected>>", lambda _e: draw_preview())
        l_cli = tk.Label(row, text="Cliente:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"])
        l_cli.pack(side="left", padx=(10, 4))
        cb_cli = ttk.Combobox(row, textvariable=slot_vars[idx][1], values=cli_options, state="readonly", width=22)
        cb_cli.pack(side="left", padx=4)
        cb_cli.bind("<<ComboboxSelected>>", lambda _e: draw_preview())
        for w in (row, l_num, l_acc, l_cli):
            w.bind("<MouseWheel>", on_wheel)
        slot_rows.append(row)
    preview_box = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
    preview_box.pack(fill="both", expand=True, padx=14, pady=2)
    tk.Label(preview_box, text=f"VISTA PREVIA ({area_w}x{area_h} px — MAXIMO 24 WOWS)", font=("Segoe UI", 8, "bold"), fg=THEME["text_muted"], bg=THEME["bg_bar"]).pack(pady=(5, 2))

    preview_canvas = tk.Canvas(preview_box, height=205, bg="#040e18", highlightthickness=0)
    preview_canvas.pack(fill="both", expand=True, padx=12, pady=(2, 8))

    def get_active_rects():
        return compute_layout_rects(layout_var.get(), int(rows_var.get()), int(cols_var.get()), area_x, area_y, area_w, area_h)

    def draw_preview(_event=None):
        preview_canvas.delete("all")
        cw = max(preview_canvas.winfo_width(), 300)
        ch = max(preview_canvas.winfo_height(), 140)
        show_borders = borders_var.get()
        rects = get_active_rects()
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
            is_primary = (idx == 0 and layout_var.get() != PRESAVED_LAYOUTS[0])
            fill_col = "#0e3152" if is_primary else THEME["bg_card"]
            preview_canvas.create_rectangle(x1, y1, x2, y2, fill=fill_col, outline=THEME["border_bright"], width=1)
            if show_borders:
                bar_h = min(16, max(8, (y2 - y1) // 5))
                preview_canvas.create_rectangle(x1, y1, x2, y1 + bar_h, fill=THEME["accent"], outline="")
                preview_canvas.create_text((x1 + x2) // 2, y1 + bar_h // 2, text=f"#{idx + 1} ({rw}x{rh})", fill="#04121f", font=("Segoe UI", 7, "bold"))
                body_y = (y1 + y2 + bar_h) // 2
            else:
                body_y = (y1 + y2) // 2
            box_w, box_h = x2 - x1, y2 - y1
            if box_w < 110 or box_h < 42:
                lbl = f"#{idx + 1} {acc_name}"
                fsize = 7
            else:
                lbl = f"#{idx + 1} {acc_name}\n[{cli_name}] ({rw}x{rh})"
                fsize = max(8, min(11, box_w // 20))
            preview_canvas.create_text((x1 + x2) // 2, body_y, text=lbl, fill=THEME["text_main"], font=("Segoe UI", fsize, "bold"), justify="center")

    last_slot_cols = [0]

    def layout_slot_rows(force=False):
        cnt = len(get_active_rects())
        avail_w = max(slots_canvas.winfo_width(), win.winfo_width() - 48)
        if avail_w >= 2600:
            num_cols = 6
        elif avail_w >= 2150:
            num_cols = 5
        elif avail_w >= 1700:
            num_cols = 4
        elif avail_w >= 1300:
            num_cols = 3
        elif avail_w >= 900:
            num_cols = 2
        else:
            num_cols = 1

        if not force and num_cols == last_slot_cols[0]:
            return
        last_slot_cols[0] = num_cols

        for c in range(6):
            slots_inner.grid_columnconfigure(c, weight=1 if c < num_cols else 0)

        for idx, row in enumerate(slot_rows):
            row.pack_forget()
            row.grid_forget()
            if idx < cnt:
                r_idx = idx // num_cols
                c_idx = idx % num_cols
                row.grid(row=r_idx, column=c_idx, sticky="ew", padx=4, pady=3)

        visible_rows = max(1, (cnt + num_cols - 1) // num_cols)
        target_h = min(320, visible_rows * 41 + 8)
        slots_canvas.configure(height=target_h)

    def refresh_ui(_event=None):
        is_custom = (layout_var.get() == PRESAVED_LAYOUTS[0])
        cb_cols.configure(state="readonly" if is_custom else "disabled")
        cb_rows.configure(state="readonly" if is_custom else "disabled")
        cnt = len(get_active_rects())
        total_lbl.config(text=f"Total: {cnt} WoW{'s' if cnt > 1 else ''}")
        layout_slot_rows(force=True)
        slots_canvas.yview_moveto(0)
        draw_preview()

    cb_layout.bind("<<ComboboxSelected>>", refresh_ui)
    cb_cols.bind("<<ComboboxSelected>>", refresh_ui)
    cb_rows.bind("<<ComboboxSelected>>", refresh_ui)
    preview_canvas.bind("<Configure>", draw_preview)
    slots_canvas.bind("<Configure>", lambda e: (slots_canvas.itemconfig(win_id, width=e.width), layout_slot_rows(force=True)))

    def load_selected_profile(_event=None):
        pname = prof_var.get()
        if pname not in profiles:
            return
        pdata = profiles[pname]
        saved_layout = pdata.get("layout", PRESAVED_LAYOUTS[0])
        layout_var.set(saved_layout if saved_layout in PRESAVED_LAYOUTS else PRESAVED_LAYOUTS[0])
        rows_var.set(pdata["rows"])
        cols_var.set(pdata["cols"])
        borders_var.set(pdata["borders"])
        prof_name_var.set(pname)
        for idx, (acc, cli) in enumerate(pdata["slots"][:24]):
            slot_vars[idx][0].set(acc if acc in acc_options else "Manual")
            slot_vars[idx][1].set(cli if cli in cli_options else active_client)
        refresh_ui()

    def save_current_profile():
        pname = prof_name_var.get().strip() or prof_var.get().strip()
        if not pname:
            messagebox.showwarning("Nombre requerido", "Escribe un nombre para el perfil.", parent=win)
            return
        cnt = len(get_active_rects())
        profiles[pname] = {
            "rows": int(rows_var.get()),
            "cols": int(cols_var.get()),
            "borders": borders_var.get(),
            "layout": layout_var.get(),
            "slots": [(slot_vars[i][0].get(), slot_vars[i][1].get()) for i in range(cnt)],
        }
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
        show_borders = borders_var.get()
        rects = get_active_rects()
        plan, used = [], set()
        for idx, rect in enumerate(rects):
            acc, cli = slot_vars[idx][0].get(), slot_vars[idx][1].get()
            if acc != "Manual":
                if acc in used:
                    messagebox.showwarning("Cuenta duplicada", f"La cuenta '{acc}' esta repetida.", parent=win)
                    return
                used.add(acc)
            plan.append((acc, cli, rect, show_borders))
        win.destroy()
        on_launch_multibox_cb(plan)