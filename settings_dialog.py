import os
import shutil
import tkinter as tk
from tkinter import filedialog, messagebox
from accounts_dialog import open_accounts_window
from config import THEME, debug_log, load_clients, normalize_github_url, save_clients, save_settings


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
    win.geometry("580x580")
    win.resizable(False, False)
    win.configure(bg=THEME["bg_panel"])
    win.transient(parent)
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 290
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 290
    win.geometry(f"+{x}+{y}")

    clients, active_client = load_clients()

    # 1. GESTOR DE CLIENTES WOW 3.3.5A
    tk.Label(
        win,
        text="🎮 PERFILES DE CLIENTE WOW (3.3.5a)",
        font=("Segoe UI", 9, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_panel"],
    ).pack(anchor="w", padx=16, pady=(10, 4))

    add_cli_box = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    add_cli_box.pack(fill="x", padx=16)

    tk.Label(add_cli_box, text="Nombre:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).grid(row=0, column=0, padx=(8, 2), pady=6)
    cli_name_var = tk.StringVar()
    tk.Entry(add_cli_box, textvariable=cli_name_var, width=18, font=("Segoe UI", 8), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").grid(row=0, column=1, padx=4, pady=6, ipady=3)

    tk.Label(add_cli_box, text="Ruta:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).grid(row=0, column=2, padx=(6, 2), pady=6)
    cli_path_var = tk.StringVar()
    tk.Entry(add_cli_box, textvariable=cli_path_var, width=22, font=("Segoe UI", 8), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").grid(row=0, column=3, padx=4, pady=6, ipady=3)

    def browse_cli_dir():
        folder = filedialog.askdirectory(parent=win, title="Selecciona la carpeta del cliente WoW 3.3.5a")
        if folder:
            cli_path_var.set(folder)
            if not cli_name_var.get().strip():
                cli_name_var.set(os.path.basename(folder))

    tk.Button(add_cli_box, text="...", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["accent"], relief="flat", padx=8, pady=2, cursor="hand2", command=browse_cli_dir).grid(row=0, column=4, padx=2, pady=6)

    cli_list_frame = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1, height=95)
    cli_list_frame.pack(fill="x", padx=16, pady=(4, 6))
    cli_list_frame.pack_propagate(False)

    selected_cli_var = tk.StringVar(value=active_client)

    def get_selected_dir():
        sel = selected_cli_var.get()
        return clients.get(sel, current_dir)

    def render_clients():
        for w in cli_list_frame.winfo_children():
            w.destroy()
        for cname, cpath in clients.items():
            row = tk.Frame(cli_list_frame, bg=THEME["bg_card"])
            row.pack(fill="x", padx=4, pady=2)
            tk.Radiobutton(
                row,
                text=f"{cname}  ({cpath})",
                variable=selected_cli_var,
                value=cname,
                font=("Segoe UI", 8, "bold"),
                fg=THEME["text_main"],
                bg=THEME["bg_card"],
                selectcolor=THEME["bg_bar"],
                activebackground=THEME["bg_card"],
                activeforeground=THEME["text_title"],
                command=load_realm_text,
            ).pack(side="left", padx=4)

            if len(clients) > 1:
                tk.Button(
                    row,
                    text="X",
                    font=("Segoe UI", 7, "bold"),
                    fg="#ff8a80",
                    bg="#3b1818",
                    relief="flat",
                    padx=6,
                    cursor="hand2",
                    command=lambda n=cname: delete_client(n),
                ).pack(side="right", padx=4, pady=2)

    def add_client():
        cname = cli_name_var.get().strip()
        cpath = cli_path_var.get().strip()
        if not cname or not cpath:
            messagebox.showwarning("Datos incompletos", "Escribe un nombre (ej. 3.3.5a enUS HD) y selecciona su carpeta.", parent=win)
            return
        if not os.path.isfile(os.path.join(cpath, "Wow.exe")):
            if not messagebox.askyesno("Wow.exe no encontrado", f"No se encontró 'Wow.exe' en:\n{cpath}\n\n¿Añadir este cliente de todas formas?", parent=win):
                return
        clients[cname] = cpath
        selected_cli_var.set(cname)
        cli_name_var.set("")
        cli_path_var.set("")
        render_clients()
        load_realm_text()

    def delete_client(cname):
        clients.pop(cname, None)
        if selected_cli_var.get() == cname:
            selected_cli_var.set(next(iter(clients)))
        render_clients()
        load_realm_text()

    tk.Button(add_cli_box, text="+ Añadir", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["border_bright"], relief="flat", padx=8, pady=2, cursor="hand2", command=add_client).grid(row=0, column=5, padx=(4, 8), pady=6)

    # 2. HERRAMIENTAS RAPIDAS: CACHE Y CUENTAS
    tools_row = tk.Frame(win, bg=THEME["bg_panel"])
    tools_row.pack(fill="x", padx=16, pady=(6, 4))

    def clear_cache():
        cache_dir = os.path.join(get_selected_dir(), "Cache")
        if not os.path.isdir(cache_dir):
            messagebox.showinfo("Caché", "La carpeta Cache ya está vacía o no existe.", parent=win)
            return
        try:
            shutil.rmtree(cache_dir)
            debug_log("TOOLS", f"Carpeta Cache eliminada: {cache_dir}")
            messagebox.showinfo("Caché limpiada", f"Caché eliminada de:\n{selected_cli_var.get()}", parent=win)
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo borrar Cache:\n{e}", parent=win)

    tk.Button(
        tools_row,
        text="🧹 Limpiar Cache (cliente activo)",
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
        text="🌐 ARCHIVO REALMLIST.WTF (CLIENTE ACTIVO)",
        font=("Segoe UI", 9, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_panel"],
    ).pack(anchor="w", padx=16, pady=(8, 4))

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
        rfile = find_realmlist_file(get_selected_dir())
        if os.path.isfile(rfile):
            with open(rfile, "r", encoding="utf-8", errors="ignore") as f:
                realm_var.set(f.read().strip())
        else:
            realm_var.set("set realmlist wow.reinosdeleyenda.org")

    def save_realm_text():
        rfile = find_realmlist_file(get_selected_dir())
        os.makedirs(os.path.dirname(rfile), exist_ok=True)
        with open(rfile, "w", encoding="utf-8") as f:
            f.write(realm_var.get().strip() + "\n")
        debug_log("TOOLS", f"realmlist.wtf guardado en {rfile}")
        messagebox.showinfo("Realmlist", f"Guardado en:\n{rfile}", parent=win)

    tk.Button(realm_row, text="Guardar Realmlist", font=("Segoe UI", 8, "bold"), fg="#04121f", bg=THEME["accent"], relief="flat", padx=10, pady=4, cursor="hand2", command=save_realm_text).pack(side="right", padx=(6, 0))
    tk.Button(realm_row, text="Restaurar RdL", font=("Segoe UI", 8, "bold"), fg=THEME["text_main"], bg=THEME["bg_card"], relief="flat", padx=8, pady=4, cursor="hand2", command=lambda: realm_var.set("set realmlist wow.reinosdeleyenda.org")).pack(side="right", padx=(6, 0))

    render_clients()
    load_realm_text()

    # 4. LISTA DE REPOSITORIOS DE GITHUB PARA ADDONS (.INI)
    tk.Label(
        win,
        text="🧩 REPOSITORIOS DE ADDONS (SOLO GITHUB — UNO POR LÍNEA)",
        font=("Segoe UI", 9, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_panel"],
    ).pack(anchor="w", padx=16, pady=(10, 4))

    repos_box = tk.Text(
        win,
        height=4,
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
    ).pack(anchor="w", padx=16, pady=(8, 0))

    # BOTONES FINALES
    btn_row = tk.Frame(win, bg=THEME["bg_panel"])
    btn_row.pack(fill="x", padx=16, pady=(10, 12))

    def save_all():
        raw_lines = repos_box.get("1.0", "end").splitlines()
        valid_repos = []
        for line in raw_lines:
            if not line.strip():
                continue
            full_url = normalize_github_url(line)
            if not full_url:
                messagebox.showwarning("URL no válida", f"Solo se permiten URLs de GitHub:\n'{line}'", parent=win)
                return
            if full_url not in valid_repos:
                valid_repos.append(full_url)

        sel_cli = selected_cli_var.get()
        new_dir = clients[sel_cli]
        save_clients(clients, sel_cli)
        save_settings(new_dir, valid_repos, tray_var.get())
        on_saved_callback(new_dir, valid_repos, tray_var.get())
        win.destroy()

    tk.Button(btn_row, text="Guardar cambios", font=("Segoe UI", 9, "bold"), fg="#04121f", bg=THEME["border_bright"], relief="flat", padx=16, pady=5, cursor="hand2", command=save_all).pack(side="right", padx=(6, 0))
    tk.Button(btn_row, text="Cancelar", font=("Segoe UI", 9), fg=THEME["text_main"], bg=THEME["bg_card"], relief="flat", padx=12, pady=5, cursor="hand2", command=win.destroy).pack(side="right")
