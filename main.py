import os
import tkinter as tk

from addon_service import scan_local_addons
from addons_dialog import open_addons_window
from config import LAUNCHER_VERSION, THEME, load_accounts, load_clients, load_settings, save_accounts, save_clients
from launcher_actions import LauncherController
from settings_dialog import open_settings_window


class RDLLauncher(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"Reinos de Leyenda - Launcher WoW 3.3.5a (v{LAUNCHER_VERSION})")
        self.geometry("1040x640")
        self.minsize(900, 560)
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
        self.header = tk.Frame(self, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
        self.header.pack(fill="x", padx=10, pady=(10, 6))

        tk.Label(
            self.header,
            text=f"❄ REINOS DE LEYENDA — LAUNCHER v{LAUNCHER_VERSION}",
            font=("Segoe UI", 13, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_bar"],
            padx=12,
            pady=8,
        ).pack(side="left")

        # 1. Boton Ajustes (extremo derecho)
        tk.Button(
            self.header,
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
            self.header,
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
        self.account_menu = tk.OptionMenu(self.header, self.account_var, "👤 Manual")
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

        self.status_lbl = tk.Label(self.header, text="Conectando...", font=("Segoe UI", 9), fg=THEME["text_muted"], bg=THEME["bg_bar"], padx=8)
        self.status_lbl.pack(side="right")

        # Banner de actualizacion del propio Launcher (oculto por defecto)
        self.update_banner = tk.Frame(self, bg=THEME["warning"], highlightbackground="#ffe082", highlightthickness=1)
        self.update_lbl = tk.Label(self.update_banner, text="", font=("Segoe UI", 9, "bold"), fg="#04121f", bg=THEME["warning"], padx=12, pady=5)
        self.update_lbl.pack(side="left")
        self.update_btn = tk.Button(self.update_banner, text="⬇ Actualizar ahora", font=("Segoe UI", 8, "bold"), fg=THEME["text_main"], bg="#04121f", relief="flat", padx=12, pady=3, cursor="hand2")
        self.update_btn.pack(side="right", padx=10, pady=4)

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

        # Panel Derecho: Logo, Selector de Cliente, Aviso Wow.exe y Lanzamiento
        right = tk.Frame(center, bg=THEME["bg_panel"], highlightbackground=THEME["border"], highlightthickness=1)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 0))

        self.logo_label = tk.Label(right, text="", fg=THEME["text_muted"], bg=THEME["bg_panel"])
        self.logo_label.pack(pady=(20, 10), padx=12, expand=True)

        # Desplegable selector de Cliente 3.3.5a
        cli_box = tk.Frame(right, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
        cli_box.pack(fill="x", padx=20, pady=(0, 8))
        tk.Label(cli_box, text="Cliente:", font=("Segoe UI", 8, "bold"), fg=THEME["text_muted"], bg=THEME["bg_card"]).pack(side="left", padx=(10, 4), pady=6)

        self.client_var = tk.StringVar()
        self.client_menu = tk.OptionMenu(cli_box, self.client_var, "3.3.5a Default")
        self.client_menu.config(
            font=("Segoe UI", 9, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_card"],
            activebackground=THEME["accent"],
            activeforeground="#04121f",
            highlightthickness=0,
            bd=0,
            cursor="hand2",
        )
        self.client_menu["menu"].config(font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_panel"], activebackground=THEME["accent"], activeforeground="#04121f", bd=0)
        self.client_menu.pack(side="left", fill="x", expand=True, padx=(0, 6), pady=4)
        self.refresh_client_dropdown()

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
        ).pack(fill="x", padx=20, pady=(4, 10))

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

    def check_wow_exe_warning(self):
        exe_path = os.path.join(self.wow_dir, "Wow.exe")
        if not os.path.isfile(exe_path):
            self.wow_warn_lbl.config(text="⚠️ No se encontró Wow.exe en la carpeta configurada.\nPulsa en '⚙ Ajustes' para seleccionar la ruta del juego.")
        else:
            self.wow_warn_lbl.config(text="")

    def show_launcher_update_banner(self, remote_ver, download_url):
        self.update_lbl.config(text=f"🚀 ¡Nueva versión del Launcher disponible: v{remote_ver} (actual: v{LAUNCHER_VERSION})!")
        self.update_btn.config(command=lambda: self.ctrl.apply_self_update(download_url))
        self.update_banner.pack(fill="x", padx=10, pady=(0, 6), after=self.header)

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

    def refresh_client_dropdown(self):
        clients, active = load_clients()
        menu = self.client_menu["menu"]
        menu.delete(0, "end")

        def select_client(cname):
            clis, _ = load_clients()
            save_clients(clis, cname)
            self.client_var.set(cname)
            self.wow_dir = clis[cname]
            self.addons_info = scan_local_addons(self.wow_dir)
            self.check_wow_exe_warning()
            self.ctrl.load_addons()

        for cname in clients.keys():
            menu.add_command(label=f"🎮 {cname}", command=lambda c=cname: select_client(c))

        self.client_var.set(active)
        self.wow_dir = clients[active]

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
        def on_settings_saved(new_dir, new_repos, new_min_tray):
            self.refresh_client_dropdown()
            self.ctrl.reload_local_and_check(new_dir, new_repos, new_min_tray)

        open_settings_window(
            self,
            self.wow_dir,
            self.repos,
            self.minimize_to_tray,
            on_settings_saved,
            self.refresh_account_dropdown,
        )


if __name__ == "__main__":
    RDLLauncher().mainloop()
