"""Panel desplazable de slots (Cuenta, Cliente, Monitor y orden) para Multiboxing."""
import tkinter as tk
from tkinter import ttk
from config import THEME


class MultiboxSlotsPanel(tk.Frame):
    def __init__(self, parent, acc_options, cli_options, active_client, mon_count, on_change_cb, get_max_slots_cb):
        super().__init__(parent, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
        self.on_change = on_change_cb
        self.get_max_slots = get_max_slots_cb
        self.mon_count = mon_count
        self.last_cols = 0

        self.canvas = tk.Canvas(self, height=48, bg=THEME["bg_panel"], highlightthickness=0)
        sb = ttk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        self.inner = tk.Frame(self.canvas, bg=THEME["bg_panel"])

        self.inner.bind("<Configure>", lambda _e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.win_id = self.canvas.create_window((0, 0), window=self.inner, anchor="nw")
        self.canvas.configure(yscrollcommand=sb.set)
        self.canvas.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")

        self.canvas.bind("<MouseWheel>", self._on_wheel)
        self.canvas.bind("<Configure>", self._on_configure)

        mon_options = ["Global"] + [f"Mon {i + 1}" for i in range(mon_count)]
        self.slot_vars = []
        for i in range(24):
            def_acc = acc_options[i + 1] if (i + 1) < len(acc_options) else "Manual"
            self.slot_vars.append((
                tk.StringVar(value=def_acc),
                tk.StringVar(value=active_client),
                tk.StringVar(value="Global"),
            ))

        self.rows = []
        for idx in range(24):
            row = tk.Frame(self.inner, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
            acc_v, cli_v, mon_v = self.slot_vars[idx]

            l_num = tk.Label(row, text=f"#{idx + 1}", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], width=4, anchor="w")
            l_num.pack(side="left", padx=(10, 4), pady=5)

            l_acc = tk.Label(row, text="Cuenta:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"])
            l_acc.pack(side="left", padx=(4, 4))
            cb_acc = ttk.Combobox(row, textvariable=acc_v, values=acc_options, state="readonly", width=16)
            cb_acc.pack(side="left", padx=4)
            cb_acc.bind("<<ComboboxSelected>>", lambda _e: self.on_change())

            l_cli = tk.Label(row, text="Cliente:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"])
            l_cli.pack(side="left", padx=(8, 4))
            cb_cli = ttk.Combobox(row, textvariable=cli_v, values=cli_options, state="readonly", width=16)
            cb_cli.pack(side="left", padx=4)
            cb_cli.bind("<<ComboboxSelected>>", lambda _e: self.on_change())

            if mon_count > 1:
                cb_mon = ttk.Combobox(row, textvariable=mon_v, values=mon_options, state="readonly", width=7)
                cb_mon.pack(side="left", padx=3)
                cb_mon.bind("<<ComboboxSelected>>", lambda _e: self.on_change())

            tk.Button(row, text="↓", font=("Segoe UI", 8, "bold"), fg=THEME["text_main"], bg=THEME["bg_panel"], relief="flat", padx=5, cursor="hand2", command=lambda i=idx: self.swap(i, min(self.get_max_slots() - 1, i + 1))).pack(side="right", padx=(2, 6))
            tk.Button(row, text="↑", font=("Segoe UI", 8, "bold"), fg=THEME["text_main"], bg=THEME["bg_panel"], relief="flat", padx=5, cursor="hand2", command=lambda i=idx: self.swap(i, max(0, i - 1))).pack(side="right", padx=2)

            for w in (row, l_num, l_acc, l_cli):
                w.bind("<MouseWheel>", self._on_wheel)
            self.rows.append(row)

    def _on_wheel(self, event):
        self.canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def _on_configure(self, event):
        self.canvas.itemconfig(self.win_id, width=event.width)
        self.relayout(force=True)

    def swap(self, idx_a, idx_b):
        if idx_a == idx_b or not (0 <= idx_a < 24 and 0 <= idx_b < 24):
            return
        va, vb = self.slot_vars[idx_a], self.slot_vars[idx_b]
        vals_a = [v.get() for v in va]
        for v_a, v_b in zip(va, vb):
            v_a.set(v_b.get())
        for v_b, val in zip(vb, vals_a):
            v_b.set(val)
        self.on_change()

    def relayout(self, force=False):
        cnt = self.get_max_slots()
        avail_w = max(self.canvas.winfo_width(), self.winfo_toplevel().winfo_width() - 48)
        num_cols = 6 if avail_w >= 2600 else (5 if avail_w >= 2150 else (4 if avail_w >= 1700 else (3 if avail_w >= 1300 else (2 if avail_w >= 900 else 1))))
        if not force and num_cols == self.last_cols:
            return
        self.last_cols = num_cols

        for c in range(6):
            self.inner.grid_columnconfigure(c, weight=1 if c < num_cols else 0)

        for idx, row in enumerate(self.rows):
            row.pack_forget()
            row.grid_forget()
            if idx < cnt:
                row.grid(row=idx // num_cols, column=idx % num_cols, sticky="ew", padx=4, pady=3)

        visible_rows = max(1, (cnt + num_cols - 1) // num_cols)
        self.canvas.configure(height=min(320, visible_rows * 41 + 8))