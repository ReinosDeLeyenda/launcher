import ctypes
from ctypes import wintypes
import tkinter as tk
from tkinter import messagebox, ttk
from config import THEME, load_accounts, load_clients, load_multibox_profiles, save_multibox_profiles


def get_work_area():
    rect = wintypes.RECT()
    # SPI_GETWORKAREA = 0x0030
    if ctypes.windll.user32.SystemParametersInfoW(0x0030, 0, ctypes.byref(rect), 0):
        return rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top
    return 0, 0, 1920, 1080


def compute_slot_rects(count, area_x, area_y, area_w, area_h):
    if count == 2:
        w = area_w // 2
        return [
            (area_x, area_y, w, area_h),
            (area_x + w, area_y, area_w - w, area_h),
        ]
    if count == 3:
        w = area_w // 3
        return [
            (area_x, area_y, w, area_h),
            (area_x + w, area_y, w, area_h),
            (area_x + w * 2, area_y, area_w - w * 2, area_h),
        ]
    # 4 ventanas: cuadricula 2x2
    w = area_w // 2
    h = area_h // 2
    return [
        (area_x, area_y, w, h),
        (area_x + w, area_y, area_w - w, h),
        (area_x, area_y + h, w, area_h - h),
        (area_x + w, area_y + h, area_w - w, area_h - h),
    ]


def open_multibox_window(parent, on_launch_multibox_cb):
    win = tk.Toplevel(parent)
    win.title("Multiboxing - Reinos de Leyenda")
    win.geometry("700x610")
    win.resizable(False, False)
    win.configure(bg=THEME["bg_panel"])
    win.transient(parent)
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 350
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 305
    win.geometry(f"+{x}+{y}")

    accounts, _ = load_accounts()
    clients, active_client = load_clients()
    profiles = load_multibox_profiles()

    acc_options = ["Manual"] + sorted(accounts.keys())
    cli_options = list(clients.keys())
    area_x, area_y, area_w, area_h = get_work_area()

    prof_bar = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    prof_bar.pack(fill="x", padx=14, pady=(12, 8))

    tk.Label(prof_bar, text="Perfil:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 6), pady=8)

    prof_var = tk.StringVar()
    prof_combo = ttk.Combobox(prof_bar, textvariable=prof_var, values=sorted(profiles.keys()), state="readonly", width=22)
    prof_combo.pack(side="left", padx=4, pady=8)

    prof_name_var = tk.StringVar()
    tk.Entry(
        prof_bar,
        textvariable=prof_name_var,
        width=20,
        font=("Segoe UI", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_bar"],
        insertbackground=THEME["text_main"],
        relief="flat",
    ).pack(side="left", padx=(10, 4), pady=8, ipady=3)

    count_var = tk.IntVar(value=2)
    slot_vars = []
    for i in range(4):
        default_acc = acc_options[i + 1] if (i + 1) < len(acc_options) else "Manual"
        slot_vars.append((tk.StringVar(value=default_acc), tk.StringVar(value=active_client)))

    layout_bar = tk.Frame(win, bg=THEME["bg_panel"])
    layout_bar.pack(fill="x", padx=14, pady=(0, 6))

    tk.Label(layout_bar, text="Ventanas:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_panel"]).pack(side="left", padx=(0, 10))
    for cnt, label in [(2, "2 WoWs (2 Columnas)"), (3, "3 WoWs (3 Columnas)"), (4, "4 WoWs (Cuadricula 2x2)")]:
        tk.Radiobutton(
            layout_bar,
            text=label,
            variable=count_var,
            value=cnt,
            font=("Segoe UI", 9, "bold"),
            fg=THEME["text_main"],
            bg=THEME["bg_panel"],
            selectcolor=THEME["bg_bar"],
            activebackground=THEME["bg_panel"],
            activeforeground=THEME["text_title"],
            command=lambda: refresh_ui(),
        ).pack(side="left", padx=8)

    preview_box = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
    preview_box.pack(fill="x", padx=14, pady=4)

    tk.Label(
        preview_box,
        text=f"VISTA PREVIA DE DISTRIBUCION EN PANTALLA ({area_w}x{area_h} px)",
        font=("Segoe UI", 8, "bold"),
        fg=THEME["text_muted"],
        bg=THEME["bg_bar"],
    ).pack(pady=(6, 2))

    canvas_w, canvas_h = 640, 210
    preview_canvas = tk.Canvas(preview_box, width=canvas_w, height=canvas_h, bg="#040e18", highlightthickness=0)
    preview_canvas.pack(pady=(2, 10))

    slots_container = tk.Frame(win, bg=THEME["bg_panel"])
    slots_container.pack(fill="both", expand=True, padx=14, pady=4)

    slot_rows = []
    for idx in range(4):
        row = tk.Frame(slots_container, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
        tk.Label(row, text=f"Ventana #{idx + 1}", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], width=11, anchor="w").pack(side="left", padx=(10, 6), pady=6)

        tk.Label(row, text="Cuenta:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).pack(side="left", padx=(4, 4))
        cb_acc = ttk.Combobox(row, textvariable=slot_vars[idx][0], values=acc_options, state="readonly", width=18)
        cb_acc.pack(side="left", padx=4)
        cb_acc.bind("<<ComboboxSelected>>", lambda _e: draw_preview())

        tk.Label(row, text="Cliente:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).pack(side="left", padx=(12, 4))
        cb_cli = ttk.Combobox(row, textvariable=slot_vars[idx][1], values=cli_options, state="readonly", width=22)
        cb_cli.pack(side="left", padx=4)
        cb_cli.bind("<<ComboboxSelected>>", lambda _e: draw_preview())

        slot_rows.append(row)

    def draw_preview():
        preview_canvas.delete("all")
        cnt = count_var.get()
        rects = compute_slot_rects(cnt, area_x, area_y, area_w, area_h)
        pad = 8
        inner_w = canvas_w - pad * 2
        inner_h = canvas_h - pad * 2

        preview_canvas.create_rectangle(pad - 2, pad - 2, pad + inner_w + 2, pad + inner_h + 2, outline=THEME["border"], width=1)

        for idx, (rx, ry, rw, rh) in enumerate(rects):
            x1 = pad + int(((rx - area_x) / area_w) * inner_w) + 3
            y1 = pad + int(((ry - area_y) / area_h) * inner_h) + 3
            x2 = pad + int(((rx - area_x + rw) / area_w) * inner_w) - 3
            y2 = pad + int(((ry - area_y + rh) / area_h) * inner_h) - 3

            acc_name = slot_vars[idx][0].get()
            cli_name = slot_vars[idx][1].get()

            preview_canvas.create_rectangle(x1, y1, x2, y2, fill=THEME["bg_card"], outline=THEME["border_bright"], width=2)
            preview_canvas.create_rectangle(x1, y1, x2, y1 + 20, fill=THEME["accent"], outline="")
            preview_canvas.create_text(
                (x1 + x2) // 2,
                y1 + 10,
                text=f"WoW #{idx + 1}  ({rw}x{rh})",
                fill="#04121f",
                font=("Segoe UI", 8, "bold"),
            )
            preview_canvas.create_text(
                (x1 + x2) // 2,
                (y1 + y2 + 16) // 2,
                text=f"{acc_name}\n[{cli_name}]",
                fill=THEME["text_main"],
                font=("Segoe UI", 8, "bold"),
                justify="center",
            )

    def refresh_ui():
        cnt = count_var.get()
        for idx, row in enumerate(slot_rows):
            if idx < cnt:
                row.pack(fill="x", pady=3)
            else:
                row.pack_forget()
        draw_preview()

    def load_selected_profile(_event=None):
        pname = prof_var.get()
        if pname not in profiles:
            return
        slots = profiles[pname]
        count_var.set(len(slots))
        prof_name_var.set(pname)
        for idx, (acc, cli) in enumerate(slots):
            slot_vars[idx][0].set(acc if acc in acc_options else "Manual")
            slot_vars[idx][1].set(cli if cli in cli_options else active_client)
        refresh_ui()

    def save_current_profile():
        pname = prof_name_var.get().strip() or prof_var.get().strip()
        if not pname:
            messagebox.showwarning("Nombre requerido", "Escribe un nombre para el perfil (ej: 1 Heal, 2 DPS).", parent=win)
            return
        cnt = count_var.get()
        profiles[pname] = [(slot_vars[i][0].get(), slot_vars[i][1].get()) for i in range(cnt)]
        save_multibox_profiles(profiles)
        prof_combo.configure(values=sorted(profiles.keys()))
        prof_var.set(pname)
        messagebox.showinfo("Perfil guardado", f"Perfil '{pname}' guardado correctamente.", parent=win)

    def delete_current_profile():
        pname = prof_var.get().strip()
        if not pname or pname not in profiles:
            return
        profiles.pop(pname, None)
        save_multibox_profiles(profiles)
        prof_combo.configure(values=sorted(profiles.keys()))
        prof_var.set("")
        prof_name_var.set("")

    prof_combo.bind("<<ComboboxSelected>>", load_selected_profile)

    tk.Button(prof_bar, text="Guardar", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["accent"], relief="flat", padx=8, pady=3, cursor="hand2", command=save_current_profile).pack(side="left", padx=4)
    tk.Button(prof_bar, text="Borrar", font=("Segoe UI", 8, "bold"), fg="#ff8a80", bg="#3b1818", relief="flat", padx=8, pady=3, cursor="hand2", command=delete_current_profile).pack(side="left", padx=4)

    if profiles:
        first_prof = sorted(profiles.keys())[0]
        prof_var.set(first_prof)
        load_selected_profile()
    else:
        refresh_ui()

    def start_multibox():
        cnt = count_var.get()
        rects = compute_slot_rects(cnt, area_x, area_y, area_w, area_h)
        plan = []
        used_accounts = set()

        for idx in range(cnt):
            acc = slot_vars[idx][0].get()
            cli = slot_vars[idx][1].get()
            if acc != "Manual":
                if acc in used_accounts:
                    messagebox.showwarning("Cuenta duplicada", f"La cuenta '{acc}' esta seleccionada mas de una vez.", parent=win)
                    return
                used_accounts.add(acc)
            plan.append((acc, cli, rects[idx]))

        win.destroy()
        on_launch_multibox_cb(plan)

    bottom_bar = tk.Frame(win, bg=THEME["bg_panel"])
    bottom_bar.pack(fill="x", padx=14, pady=(6, 12))

    tk.Button(
        bottom_bar,
        text="LANZAR MULTIBOXING",
        font=("Segoe UI", 10, "bold"),
        fg="#04121f",
        bg=THEME["border_bright"],
        relief="flat",
        padx=18,
        pady=6,
        cursor="hand2",
        command=start_multibox,
    ).pack(side="right", padx=(6, 0))

    tk.Button(
        bottom_bar,
        text="Cancelar",
        font=("Segoe UI", 9),
        fg=THEME["text_main"],
        bg=THEME["bg_card"],
        relief="flat",
        padx=14,
        pady=6,
        cursor="hand2",
        command=win.destroy,
    ).pack(side="right")
