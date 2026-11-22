import tkinter as tk
from tkinter import messagebox
from config import THEME, load_accounts, save_accounts


def open_accounts_window(parent, on_changed_cb):
    win = tk.Toplevel(parent)
    win.title("Gestor de Cuentas - Reinos de Leyenda")
    win.geometry("520x470")
    win.resizable(False, False)
    win.configure(bg=THEME["bg_panel"])
    win.transient(parent)
    win.grab_set()

    parent.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 260
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 235
    win.geometry(f"+{x}+{y}")

    accounts, active_alias = load_accounts()

    # AVISO DE SEGURIDAD (CIFRADO DPAPI + ENVIO AL CLIENTE)
    info_box = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    info_box.pack(fill="x", padx=14, pady=(12, 8))
    tk.Label(
        info_box,
        text="🔒 SEGURIDAD DE CUENTAS (WINDOWS DPAPI):\n"
             "Las contraseñas se almacenan cifradas mediante Windows DPAPI (vinculadas a tu\n"
             "sesión de Windows) y solo se descifran en memoria al enviarlas a WoW 3.3.5a.",
        font=("Segoe UI", 8, "bold"),
        fg=THEME["text_title"],
        bg=THEME["bg_card"],
        justify="left",
        padx=10,
        pady=6,
    ).pack(fill="x")

    # FORMULARIO PARA AÑADIR CUENTA
    form = tk.Frame(win, bg=THEME["bg_card"], highlightbackground=THEME["border"], highlightthickness=1)
    form.pack(fill="x", padx=14, pady=4)

    tk.Label(form, text="Añadir / Editar cuenta:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_card"]).grid(row=0, column=0, columnspan=4, sticky="w", padx=8, pady=(6, 4))

    tk.Label(form, text="Alias:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).grid(row=1, column=0, sticky="w", padx=(8, 2))
    alias_var = tk.StringVar()
    tk.Entry(form, textvariable=alias_var, width=14, font=("Segoe UI", 8), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").grid(row=1, column=1, padx=4, pady=4, ipady=3)

    tk.Label(form, text="Usuario:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).grid(row=1, column=2, sticky="w", padx=(6, 2))
    user_var = tk.StringVar()
    tk.Entry(form, textvariable=user_var, width=18, font=("Segoe UI", 8), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").grid(row=1, column=3, padx=(4, 8), pady=4, ipady=3)

    tk.Label(form, text="Clave:", font=("Segoe UI", 8), fg=THEME["text_muted"], bg=THEME["bg_card"]).grid(row=2, column=0, sticky="w", padx=(8, 2), pady=(0, 8))
    pass_var = tk.StringVar()
    tk.Entry(form, textvariable=pass_var, show="*", width=14, font=("Segoe UI", 8), fg=THEME["text_main"], bg=THEME["bg_bar"], insertbackground=THEME["text_main"], relief="flat").grid(row=2, column=1, padx=4, pady=(0, 8), ipady=3)

    # LISTA DE CUENTAS GUARDADAS
    tk.Label(win, text="Selecciona la cuenta para iniciar sesión automáticamente:", font=("Segoe UI", 9, "bold"), fg=THEME["text_title"], bg=THEME["bg_panel"]).pack(anchor="w", padx=14, pady=(10, 4))

    list_frame = tk.Frame(win, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1, height=160)
    list_frame.pack(fill="x", padx=14)
    list_frame.pack_propagate(False)

    selected_var = tk.StringVar(value=active_alias)

    def render_accounts():
        for w in list_frame.winfo_children():
            w.destroy()

        tk.Radiobutton(
            list_frame,
            text="Ninguna (escribir usuario y contraseña manualmente en el juego)",
            variable=selected_var,
            value="",
            font=("Segoe UI", 8),
            fg=THEME["text_muted"],
            bg=THEME["bg_bar"],
            selectcolor=THEME["bg_panel"],
            activebackground=THEME["bg_bar"],
            activeforeground=THEME["text_title"],
            command=lambda: (save_accounts(accounts, ""), on_changed_cb()),
        ).pack(anchor="w", padx=8, pady=4)

        for alias, (user, _) in accounts.items():
            row = tk.Frame(list_frame, bg=THEME["bg_card"])
            row.pack(fill="x", padx=6, pady=2)

            tk.Radiobutton(
                row,
                text=f"{alias}  ({user})",
                variable=selected_var,
                value=alias,
                font=("Segoe UI", 9, "bold"),
                fg=THEME["text_main"],
                bg=THEME["bg_card"],
                selectcolor=THEME["bg_bar"],
                activebackground=THEME["bg_card"],
                activeforeground=THEME["text_title"],
                command=lambda a=alias: (save_accounts(accounts, a), on_changed_cb()),
            ).pack(side="left", padx=6, pady=2)

            tk.Button(
                row,
                text="Eliminar",
                font=("Segoe UI", 7, "bold"),
                fg="#ff8a80",
                bg="#3b1818",
                relief="flat",
                padx=8,
                cursor="hand2",
                command=lambda a=alias: delete_acc(a),
            ).pack(side="right", padx=6, pady=3)

    def add_acc():
        a = alias_var.get().strip().lower()
        u = user_var.get().strip()
        p = pass_var.get().strip()
        if not a or not u or not p:
            messagebox.showwarning("Campos incompletos", "Rellena Alias, Usuario y Clave.", parent=win)
            return
        accounts[a] = (u, p)
        selected_var.set(a)
        save_accounts(accounts, a)
        alias_var.set("")
        user_var.set("")
        pass_var.set("")
        render_accounts()
        on_changed_cb()

    def delete_acc(alias):
        accounts.pop(alias, None)
        new_active = "" if selected_var.get() == alias else selected_var.get()
        selected_var.set(new_active)
        save_accounts(accounts, new_active)
        render_accounts()
        on_changed_cb()

    tk.Button(
        form,
        text="+ Guardar cuenta",
        font=("Segoe UI", 8, "bold"),
        fg="#04121f",
        bg=THEME["accent"],
        relief="flat",
        padx=10,
        pady=3,
        cursor="hand2",
        command=add_acc,
    ).grid(row=2, column=2, columnspan=2, sticky="e", padx=8, pady=(0, 8))

    render_accounts()

    tk.Button(
        win,
        text="Cerrar",
        font=("Segoe UI", 9, "bold"),
        fg="#04121f",
        bg=THEME["border_bright"],
        relief="flat",
        padx=18,
        pady=5,
        cursor="hand2",
        command=win.destroy,
    ).pack(pady=12)
