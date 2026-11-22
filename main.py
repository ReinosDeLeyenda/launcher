import tkinter as tk

from addon_service import scan_local_addons
from addons_dialog import open_addons_window
from config import THEME, load_accounts, load_settings, save_accounts
from launcher_actions import LauncherController
from settings_dialog import open_settings_window


class RDLLauncher(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Reinos de Leyenda - Launcher WoW 3.3.5a")
        self.geometry("1040x620")
        self.minsize(900, 540)
        self.configure(bg=THEME["bg_main"])

        self.wow_dir, self.repos, self.minimize_to_tray = load_settings()
        self.addons_info = scan_local_addons(self.wow_dir)
        self.addons_listener = None
        self.logo_photo = None
        self.addons_checking = False
        self.spinner_idx = 0

        self.ctrl = LauncherController(self)
        self.protocol("WM_DELETE_WINDOW", self.ctrl.on_close_window)

        self.build_ui()
        self.ctrl.refresh_all()

    def build_ui(self):
        header = tk.Frame(self, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
        header.pack(fill="x", padx=10, pady=(10, 6))

        tk.Label(
            header,
            text="❄ REINOS DE LEYENDA — LAUNCHER OFICIAL (3.3.5a)",
            font=("Segoe UI", 13, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_bar"],
            padx=12,
            pady=8,
        ).pack(side="left")

        # 1. Boton Ajustes (extremo derecho)
        tk.Button(
            header,
            text="⚙ Ajustes",
            font=("Segoe UI", 9, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_card"],
            activebackground=THEME["accent"],
            activeforeground="#04121f",
            relief="flat",
            padx=10,
            pady=4,
            cursor="hand2",
            command=self.open_settings_dialog,
        ).pack(side="right", padx=(6, 10), pady=6)

        # 2. Boton Addons (a la izquierda de Ajustes)
        self.addons_btn = tk.Button(
            header,
            text="🧩 Addons",
            font=("Segoe UI", 9, "bold"),
            fg="#04121f",
            bg=THEME["accent"],
            activebackground=THEME["border_bright"],
            relief="flat",
            padx=12,
            pady=4,
            cursor="hand2",
            command=self.open_addons_dialog,
        )
        self.addons_btn.pack(side="right", padx=(6, 0), pady=6)

        # 3. Desplegable de seleccion de cuenta (a la izquierda de Addons)
        self.account_var = tk.StringVar()
        self.account_menu = tk.OptionMenu(header, self.account_var, "👤 Manual")
        self.account_menu.config(
            font=("Segoe UI", 9, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_card"],
            activebackground=THEME["accent"],
            activeforeground="#04121f",
            highlightthickness=0,
            bd=0,
            padx=8,
            pady=4,
            cursor="hand2",
        )
        self.account_menu["menu"].config(
            font=("Segoe UI", 9),
            fg=THEME["text_main"],
            bg=THEME["bg_panel"],
            activebackground=THEME["accent"],
            activeforeground="#04121f",
            bd=0,
        )
        self.account_menu.pack(side="right", padx=(6, 0), pady=6)
        self.refresh_account_dropdown()

        self.status_lbl = tk.Label(header, text="Conectando...", font=("Segoe UI", 9), fg=THEME["text_muted"], bg=THEME["bg_bar"], padx=8)
        self.status_lbl.pack(side="right")

        center = tk.Frame(self, bg=THEME["bg_main"])
        center.pack(fill="both", expand=True, padx=10, pady=(4, 10))
        center.grid_columnconfigure(0, weight=3)
        center.grid_columnconfigure(1, weight=2)
        center.grid_rowconfigure(0, weight=1)

        # Panel Izquierdo: Noticias
        left = tk.Frame(center, bg=THEME["bg_panel"], highlightbackground=THEME["border"], highlightthickness=1)
        left.grid(row=0, column=0, sticky="nsew", padx=(0, 6))

        news_top = tk.Frame(left, bg=THEME["bg_card"])
        news_top.pack(fill="x")
        tk.Label(news_top, text="📰 ÚLTIMAS NOTICIAS — REINOSDELEYENDA.ORG", font=("Segoe UI", 10, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"], padx=10, pady=6).pack(side="left")
        tk.Button(news_top, text="↻", font=("Segoe UI", 10, "bold"), fg=THEME["text_main"], bg=THEME["bg_panel"], bd=0, padx=8, cursor="hand2", command=self.ctrl.load_news).pack(side="right", padx=6, pady=4)

        news_box = tk.Frame(left, bg=THEME["bg_panel"])
        news_box.pack(fill="both", expand=True, padx=4, pady=4)
        self.news_canvas = tk.Canvas(news_box, bg=THEME["bg_panel"], highlightthickness=0)
        news_sb = tk.Scrollbar(news_box, orient="vertical", command=self.news_canvas.yview)
        self.news_inner = tk.Frame(self.news_canvas, bg=THEME["bg_panel"])

        self.news_inner.bind("<Configure>", lambda e: self.news_canvas.configure(scrollregion=self.news_canvas.bbox("all")))
        win_id = self.news_canvas.create_window((0, 0), window=self.news_inner, anchor="nw")
        self.news_canvas.bind("<Configure>", lambda e: self.news_canvas.itemconfig(win_id, width=e.width))
        self.news_canvas.configure(yscrollcommand=news_sb.set)
        self.news_canvas.pack(side="left", fill="both", expand=True)
        news_sb.pack(side="right", fill="y")

        # Panel Derecho: Logo y Lanzamiento
        right = tk.Frame(center, bg=THEME["bg_panel"], highlightbackground=THEME["border"], highlightthickness=1)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 0))

        self.logo_label = tk.Label(right, text="", fg=THEME["text_muted"], bg=THEME["bg_panel"])
        self.logo_label.pack(pady=(24, 12), padx=12, expand=True)

        tk.Button(
            right,
            text="▶  JUGAR AHORA",
            font=("Segoe UI", 15, "bold"),
            fg="#04121f",
            bg=THEME["border_bright"],
            activebackground=THEME["accent"],
            relief="flat",
            pady=14,
            cursor="hand2",
            command=self.ctrl.launch_wow,
        ).pack(fill="x", padx=20, pady=(6, 22))

        self.wow_warn_lbl = tk.Label(
            right,
            text="",
            font=("Segoe UI", 8, "bold"),
            fg="#ff8a80",
            bg=THEME["bg_panel"],
            wraplength=320,
            justify="center",
        )
        self.wow_warn_lbl.pack(fill="x", padx=20, pady=(0, 14))
        self.check_wow_exe_warning()

    def set_status(self, msg):
        self.after(0, lambda m=msg: self.status_lbl.config(text=m))

    def notify_addons_dialog(self):
        if self.addons_listener:
            self.addons_listener(self.addons_info, self.addons_checking)

    def start_addons_spinner(self):
        self.addons_checking = True
        self.notify_addons_dialog()
        self._animate_addons_spinner()

    def stop_addons_spinner(self):
        self.addons_checking = False
        self.update_addons_button_state()
        self.notify_addons_dialog()

    def _animate_addons_spinner(self):
        if not self.addons_checking:
            return
        frames = ["◐", "◓", "◑", "◒"]
        self.addons_btn.config(text=f"{frames[self.spinner_idx % 4]} Addons", bg=THEME["accent"], fg="#04121f")
        self.spinner_idx += 1
        self.after(140, self._animate_addons_spinner)

    def update_addons_button_state(self):
        if self.addons_checking:
            return
        has_updates = any(
            repo_url != "Local" and local_ver is not None and local_ver != remote_ver and remote_ver != "Desconocida"
            for _, local_ver, remote_ver, repo_url, _ in self.addons_info
        )
        if has_updates:
            self.addons_btn.config(text="🧩 Addons (¡Actualizar!)", bg=THEME["warning"], fg="#04121f")
        else:
            self.addons_btn.config(text="🧩 Addons", bg=THEME["success"], fg="#04121f")

    def refresh_account_dropdown(self):
        accounts, active = load_accounts()
        menu = self.account_menu["menu"]
        menu.delete(0, "end")

        def select_account(alias):
            accs, _ = load_accounts()
            save_accounts(accs, alias)
            self.account_var.set(f"👤 {alias}" if alias else "👤 Manual")

        menu.add_command(label="Manual (sin auto-login)", command=lambda: select_account(""))
        for alias in sorted(accounts.keys()):
            menu.add_command(label=f"👤 {alias}", command=lambda a=alias: select_account(a))

        self.account_var.set(f"👤 {active}" if active and active in accounts else "👤 Manual")

    def open_addons_dialog(self):
        open_addons_window(
            self,
            self.addons_info,
            self.repos,
            self.addons_checking,
            self.ctrl.load_addons,
            self.ctrl.start_install,
            lambda cb: setattr(self, "addons_listener", cb),
        )

    def open_settings_dialog(self):
        open_settings_window(
            self,
            self.wow_dir,
            self.repos,
            self.minimize_to_tray,
            self.ctrl.reload_local_and_check,
            self.refresh_account_dropdown,
        )

    def check_wow_exe_warning(self):
        import os
        exe_path = os.path.join(self.wow_dir, "Wow.exe")
        if not os.path.isfile(exe_path):
            self.wow_warn_lbl.config(text="⚠️ No se encontró Wow.exe en la carpeta configurada.\nPulsa en '⚙ Ajustes' para seleccionar la ruta del juego.")
        else:
            self.wow_warn_lbl.config(text="")

if __name__ == "__main__":
    RDLLauncher().mainloop()
