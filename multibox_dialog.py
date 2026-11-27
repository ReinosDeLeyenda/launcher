import tkinter as tk
from tkinter import messagebox, ttk
from config import THEME, load_accounts, load_clients, load_multibox_profiles, save_multibox_profiles
from multibox_canvas import MultiboxPreviewCanvas
from multibox_slots import MultiboxSlotsPanel
from multibox_layouts import (
    MONITOR_ARRANGEMENTS,
    PRESAVED_LAYOUTS,
    compute_layout_rects,
    compute_monitor_subrects,
    get_monitors_info,
)

def open_multibox_window(parent, on_launch_multibox_cb, debug_args=None):
    win = tk.Toplevel(parent)
    win.title("Multiboxing - Reinos de Leyenda")
    win.geometry("940x700")
    win.minsize(820, 650)
    win.resizable(True, True)
    win.configure(bg=THEME["bg_panel"])
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 470
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 350
    win.geometry(f"+{x}+{y}")

    accounts, _ = load_accounts()
    clients, active_client = load_clients()
    profiles = load_multibox_profiles()

    acc_options = ["Manual"] + sorted(accounts.keys())
    cli_options = list(clients.keys())

    base_monitors = get_monitors_info(debug_args=debug_args)
    mon_order = list(range(len(base_monitors)))
    mon_portrait = {i: False for i in range(len(base_monitors))}
    mon_arrange_var = tk.StringVar(value=next(iter(MONITOR_ARRANGEMENTS)))
    sel_state = {"idx": -1}
    mon_split_modes = {}
    mon_slot_zones = {}

    def get_arranged_monitors():
        arr = mon_arrange_var.get()
        ordered_indices = list(mon_order)
        if arr == "Horizontal Invertido (3 | 2 | 1)" and len(ordered_indices) > 1:
            ordered_indices = list(reversed(ordered_indices))
        res = []
        cur_x, cur_y = 0, 0
        for orig_i in ordered_indices:
            label, (ox, oy, w, h) = base_monitors[orig_i]
            if mon_portrait.get(orig_i, False):
                w, h = h, w
            clean_lbl = next(iter(label.split(" — ")))
            orient_tag = " [Vertical]" if mon_portrait.get(orig_i, False) else ""
            if arr == "Real (Windows)" and not any(mon_portrait.values()):
                res.append((f"{clean_lbl}{orient_tag} — {w}x{h}", (ox, oy, w, h)))
            else:
                res.append((f"{clean_lbl}{orient_tag} — {w}x{h}", (cur_x, cur_y, w, h)))
                if arr == "Vertical (Arriba / Abajo)":
                    cur_y += h
                else:
                    cur_x += w
        return res

    def get_monitor_dropdown_items():
        mons = get_arranged_monitors()
        items = list(mons)
        if len(mons) > 1:
            min_x = min(bx for _, (bx, by, bw, bh) in mons)
            min_y = min(by for _, (bx, by, bw, bh) in mons)
            max_x = max(bx + bw for _, (bx, by, bw, bh) in mons)
            max_y = max(by + bh for _, (bx, by, bw, bh) in mons)
            items.append((f"Todos ({len(mons)} monitores) — {max_x - min_x}x{max_y - min_y}", (min_x, min_y, max_x - min_x, max_y - min_y)))
        return items

    monitors_list = get_monitor_dropdown_items()
    monitor_names = [label for label, _rect in monitors_list]

    prof_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    prof_bar.pack(fill="x", padx=14, pady=(10, 6))
    tk.Label(prof_bar, text="Perfil:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 6), pady=7)
    prof_var = tk.StringVar()
    prof_combo = ttk.Combobox(prof_bar, textvariable=prof_var, values=sorted(profiles.keys()), state="readonly", width=22)
    prof_combo.pack(side="left", padx=4, pady=7)
    prof_name_var = tk.StringVar()
    tk.Entry(prof_bar, textvariable=prof_name_var, width=22, font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").pack(side="left", padx=(10, 4), pady=7, ipady=3)

    mon_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    mon_bar.pack(fill="x", padx=14, pady=(0, 6))
    tk.Label(mon_bar, text="Monitor destino:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 4), pady=6)
    monitor_var = tk.StringVar(value=next(iter(monitor_names)))
    cb_monitor = ttk.Combobox(mon_bar, textvariable=monitor_var, values=monitor_names, state="readonly", width=28)
    cb_monitor.pack(side="left", padx=(0, 10))
    tk.Label(mon_bar, text="Orden pantallas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(4, 4))
    cb_arrange = ttk.Combobox(mon_bar, textvariable=mon_arrange_var, values=MONITOR_ARRANGEMENTS, state="readonly", width=24)
    cb_arrange.pack(side="left", padx=(0, 6))

    def sync_monitor_dropdown(select_pos=None):
        nonlocal monitors_list, monitor_names
        prev_idx = max(0, cb_monitor.current()) if select_pos is None else select_pos
        monitors_list = get_monitor_dropdown_items()
        monitor_names = [lbl for lbl, _r in monitors_list]
        cb_monitor.configure(values=monitor_names)
        new_idx = min(prev_idx, len(monitor_names) - 1)
        monitor_var.set(monitor_names[new_idx])

    def move_selected_monitor(delta):
        sel_idx = cb_monitor.current()
        if 0 <= sel_idx < len(mon_order):
            new_pos = sel_idx + delta
            if 0 <= new_pos < len(mon_order):
                mon_order[sel_idx], mon_order[new_pos] = mon_order[new_pos], mon_order[sel_idx]
                sync_monitor_dropdown(select_pos=new_pos)
                refresh_ui()

    def toggle_monitor_portrait():
        sel_idx = cb_monitor.current()
        if 0 <= sel_idx < len(mon_order):
            orig_i = mon_order[sel_idx]
            mon_portrait[orig_i] = not mon_portrait.get(orig_i, False)
            sync_monitor_dropdown(select_pos=sel_idx)
            refresh_ui()

    btn_mon_left = tk.Button(mon_bar, text="◀ Izq", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["accent"], relief="flat", padx=7, pady=2, cursor="hand2", command=lambda: move_selected_monitor(-1))
    btn_mon_left.pack(side="left", padx=2)
    btn_mon_right = tk.Button(mon_bar, text="Der ▶", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["accent"], relief="flat", padx=7, pady=2, cursor="hand2", command=lambda: move_selected_monitor(1))
    btn_mon_right.pack(side="left", padx=2)
    btn_mon_turn = tk.Button(mon_bar, text="↻ Girar 90°", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["border_bright"], relief="flat", padx=8, pady=2, cursor="hand2", command=toggle_monitor_portrait)
    btn_mon_turn.pack(side="left", padx=(6, 10))
    if len(base_monitors) <= 1:
        cb_arrange.configure(state="disabled")
        btn_mon_left.configure(state="disabled")
        btn_mon_right.configure(state="disabled")
    layout_var = tk.StringVar(value=next(iter(PRESAVED_LAYOUTS)))
    rows_var = tk.IntVar(value=1)
    cols_var = tk.IntVar(value=2)
    borders_var = tk.BooleanVar(value=False)

    grid_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    grid_bar.pack(fill="x", padx=14, pady=(0, 6))
    tk.Label(grid_bar, text="Pre-saved:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 4), pady=6)
    cb_layout = ttk.Combobox(grid_bar, textvariable=layout_var, values=PRESAVED_LAYOUTS, state="readonly", width=26)
    cb_layout.pack(side="left", padx=(0, 10))
    tk.Label(grid_bar, text="Columnas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(2, 4), pady=6)
    cb_cols = ttk.Combobox(grid_bar, textvariable=cols_var, values=[1, 2, 3, 4, 5, 6], state="readonly", width=3)
    cb_cols.pack(side="left", padx=(0, 10))
    tk.Label(grid_bar, text="Filas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(2, 4))
    cb_rows = ttk.Combobox(grid_bar, textvariable=rows_var, values=[1, 2, 3, 4], state="readonly", width=3)
    cb_rows.pack(side="left", padx=(0, 10))
    total_lbl = tk.Label(grid_bar, text="Total: 2 WoWs", font=("Segoe UI", 9, "bold"), fg=THEME["accent"], bg=THEME["bg_card"])
    total_lbl.pack(side="left", padx=6)
    tk.Checkbutton(grid_bar, text="Mostrar bordes", variable=borders_var, font=("Segoe UI", 9, "bold"), fg=THEME["text_main"], bg=THEME["bg_card"], selectcolor=THEME["bg_bar"], activebackground=THEME["bg_card"], activeforeground=THEME["text_title"], cursor="hand2", command=lambda: draw_preview()).pack(side="right", padx=10)

    bottom_bar = tk.Frame(win, bg=THEME["bg_panel"])
    bottom_bar.pack(side="bottom", fill="x", padx=14, pady=(4, 10))
    tk.Button(bottom_bar, text="LANZAR MULTIBOXING", font=("Segoe UI", 10, "bold"), fg="#04121f", bg=THEME["border_bright"], relief="flat", padx=18, pady=6, cursor="hand2", command=lambda: start_multibox()).pack(side="right", padx=(6, 0))
    tk.Button(bottom_bar, text="Cancelar", font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_card"], relief="flat", padx=14, pady=6, cursor="hand2", command=win.destroy).pack(side="right")

    slots_panel = MultiboxSlotsPanel(
        win,
        acc_options=acc_options,
        cli_options=cli_options,
        active_client=active_client,
        mon_count=len(base_monitors),
        on_change_cb=lambda: draw_preview(),
        get_max_slots_cb=lambda: len(get_active_rects()),
    )
    slots_panel.pack(side="bottom", fill="x", expand=False, padx=14, pady=(4, 4))
    slot_vars = slots_panel.slot_vars

    def swap_slots(idx_a, idx_b):
        slots_panel.swap(idx_a, idx_b)
    def get_current_area():
        idx = cb_monitor.current()
        if 0 <= idx < len(monitors_list):
            _lbl, rect = monitors_list[idx]
            return rect
        _lbl, rect = next(iter(monitors_list))
        return rect

    def get_active_rects():
        ax, ay, aw, ah = get_current_area()
        base_rects = compute_layout_rects(layout_var.get(), int(rows_var.get()), int(cols_var.get()), ax, ay, aw, ah)
        arranged = get_arranged_monitors()
        if len(arranged) <= 1 and not mon_split_modes:
            return base_rects

        final_rects = list(base_rects)
        for m_i, (_mlbl, (mx, my, mw, mh)) in enumerate(arranged):
            mode = mon_split_modes.get(m_i, "auto")
            zones = mon_slot_zones.get(m_i)
            assigned = [i for i in range(len(base_rects)) if next(reversed(slot_vars[i])).get() == f"Mon {m_i + 1}"]
            if mode == "auto" and not assigned:
                continue
            if zones is None:
                min_zones = 2 if mode != "auto" else max(1, len(assigned))
                zones = list(assigned) + [None] * max(0, min_zones - len(assigned))
                mon_slot_zones[m_i] = zones
            else:
                for s_i in assigned:
                    if s_i not in zones:
                        if None in zones:
                            zones[zones.index(None)] = s_i
                        else:
                            zones.append(s_i)
                for z_i, val in enumerate(zones):
                    if val is not None and val not in assigned:
                        zones[z_i] = None

            sub_rects = compute_monitor_subrects(mode, len(zones), mx, my, mw, mh, int(cols_var.get()))
            for z_i, s_i in enumerate(zones):
                if s_i is not None and 0 <= s_i < len(final_rects):
                    final_rects[s_i] = sub_rects[z_i]
        return final_rects

    def on_drop_empty_zone(src_idx, m_idx, z_idx):
        for z_list in mon_slot_zones.values():
            for k, v in enumerate(z_list):
                if v == src_idx:
                    z_list[k] = None
        next(reversed(slot_vars[src_idx])).set(f"Mon {m_idx + 1}")
        mon_slot_zones.setdefault(m_idx, [])
        while len(mon_slot_zones[m_idx]) <= z_idx:
            mon_slot_zones[m_idx].append(None)
        mon_slot_zones[m_idx][z_idx] = src_idx
        draw_preview()

    def on_drop_monitor(src_idx, m_idx):
        if len(base_monitors) > 1:
            for z_list in mon_slot_zones.values():
                for k, v in enumerate(z_list):
                    if v == src_idx:
                        z_list[k] = None
            next(reversed(slot_vars[src_idx])).set(f"Mon {m_idx + 1}")
            draw_preview()

    def apply_monitor_split(m_idx, mode):
        rects_now = get_active_rects()
        arranged_now = get_arranged_monitors()
        if not (0 <= m_idx < len(arranged_now)):
            return
        _lbl, (mx, my, mw, mh) = arranged_now[m_idx]
        if mode == "auto":
            mon_split_modes.pop(m_idx, None)
            mon_slot_zones.pop(m_idx, None)
            draw_preview()
            return
        inside = []
        for s_i, (rx, ry, rw, rh) in enumerate(rects_now):
            cx, cy = rx + rw // 2, ry + rh // 2
            if mx <= cx <= mx + mw and my <= cy <= my + mh:
                inside.append(s_i)
                next(reversed(slot_vars[s_i])).set(f"Mon {m_idx + 1}")
        num_zones = max(2, len(inside))
        mon_split_modes[m_idx] = mode
        mon_slot_zones[m_idx] = list(inside) + [None] * (num_zones - len(inside))
        draw_preview()

    def get_slot_acc_cli(idx):
        acc_v, cli_v, *_ = slot_vars[idx]
        return acc_v.get(), cli_v.get()

    preview_widget = MultiboxPreviewCanvas(win, {
        "get_active_rects": get_active_rects,
        "get_arranged_monitors": get_arranged_monitors,
        "get_current_area": get_current_area,
        "get_split_state": lambda: (mon_split_modes, mon_slot_zones),
        "get_visual_flags": lambda: (borders_var.get(), layout_var.get(), int(cols_var.get())),
        "get_slot_info": get_slot_acc_cli,
        "swap_slots": lambda a, b: (preview_widget.clear_selection(), swap_slots(a, b)),
        "drop_on_empty_zone": on_drop_empty_zone,
        "drop_on_monitor": on_drop_monitor,
        "split_monitor": apply_monitor_split,
    })
    preview_widget.pack(fill="both", expand=True, padx=14, pady=2)

    def draw_preview(_event=None):
        preview_widget.draw()
    def refresh_ui(_event=None):
        is_custom = (layout_var.get() == next(iter(PRESAVED_LAYOUTS)))
        cb_cols.configure(state="readonly" if is_custom else "disabled")
        cb_rows.configure(state="readonly" if is_custom else "disabled")
        cnt = len(get_active_rects())
        total_lbl.config(text=f"Total: {cnt} WoW{'s' if cnt > 1 else ''}")
        slots_panel.relayout(force=True)
        slots_panel.canvas.yview_moveto(0)
        draw_preview()

    cb_monitor.bind("<<ComboboxSelected>>", refresh_ui)
    cb_arrange.bind("<<ComboboxSelected>>", lambda _e: (sync_monitor_dropdown(), refresh_ui()))
    cb_layout.bind("<<ComboboxSelected>>", refresh_ui)
    cb_cols.bind("<<ComboboxSelected>>", refresh_ui)
    cb_rows.bind("<<ComboboxSelected>>", refresh_ui)
    
    

    def load_selected_profile(_event=None):
        pname = prof_var.get()
        if pname not in profiles:
            return
        pdata = profiles[pname]
        saved_layout = pdata.get("layout", next(iter(PRESAVED_LAYOUTS)))
        layout_var.set(saved_layout if saved_layout in PRESAVED_LAYOUTS else next(iter(PRESAVED_LAYOUTS)))
        mon_idx = pdata.get("monitor", 0)
        if 0 <= mon_idx < len(monitor_names):
            monitor_var.set(monitor_names[mon_idx])
        rows_var.set(pdata["rows"])
        cols_var.set(pdata["cols"])
        borders_var.set(pdata["borders"])
        prof_name_var.set(pname)
        for idx, (acc, cli) in enumerate(pdata["slots"][:24]):
            acc_v, cli_v, mon_v = slot_vars[idx]
            acc_v.set(acc if acc in acc_options else "Manual")
            cli_v.set(cli if cli in cli_options else active_client)
            mon_v.set("Global")
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
            "monitor": max(0, cb_monitor.current()),
            "slots": [(acc_v.get(), cli_v.get()) for acc_v, cli_v, _ in (slot_vars[i] for i in range(cnt))],
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
        prof_var.set(next(iter(sorted(profiles.keys()))))
        load_selected_profile()
    else:
        refresh_ui()

    def start_multibox():
        show_borders = borders_var.get()
        rects = get_active_rects()
        plan, used = [], set()
        for idx, rect in enumerate(rects):
            acc_v, cli_v, *_ = slot_vars[idx]
            acc, cli = acc_v.get(), cli_v.get()
            if acc != "Manual":
                if acc in used:
                    messagebox.showwarning("Cuenta duplicada", f"La cuenta '{acc}' esta repetida.", parent=win)
                    return
                used.add(acc)
            plan.append((acc, cli, rect, show_borders))
        win.destroy()
        on_launch_multibox_cb(plan)