"""Tkinter chat window for the Reinos de Leyenda launcher."""

from configparser import Error as ConfigurationError
from datetime import datetime
import queue
import tkinter as tk
from tkinter import ttk

from chat_endpoint import DEFAULT_HOST, DEFAULT_PORT, read_realmlist, validate_endpoint
from chat_session import SEND_MODES, ChatSession
from config import THEME, load_accounts


class WoWChatWindow(tk.Toplevel):
    def __init__(self, parent, realmlist_path, saved_alias):
        super().__init__(parent)
        self.title("Chat WoW 3.3.5a | Reinos de Leyenda")
        self.geometry("740x620")
        self.minsize(620, 530)
        self.configure(bg=THEME["bg_main"])
        self.transient(parent)
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.saved_alias = saved_alias
        self.session = None
        self.poll_job = None
        self.choice_kind = None
        self.last_whisperer = ""
        self.ready = False
        self.had_error = False
        self.line_count = 0

        host, port = read_realmlist(realmlist_path)
        self.host = tk.StringVar(self, host)
        self.port = tk.StringVar(self, str(port))
        self.username = tk.StringVar(self)
        self.password = tk.StringVar(self)
        self.use_saved = tk.BooleanVar(self)
        self.status = tk.StringVar(self, "Desconectado")
        self.selection = tk.StringVar(self)
        self.mode = tk.StringVar(self, "Decir")
        self.target = tk.StringVar(self)
        self.body = tk.StringVar(self)
        self._build()

    def _label(self, parent, text=None, *, var=None, title=False, bg=None):
        return tk.Label(parent, text=text, textvariable=var, anchor="w",
                        bg=bg or THEME["bg_panel"],
                        fg=THEME["text_title" if title else "text_muted"],
                        font=("Segoe UI", 10, "bold" if title else "normal"))

    def _button(self, parent, text, command, primary=False):
        return tk.Button(parent, text=text, command=command, relief="flat", padx=11,
                         pady=4, bg=THEME["accent" if primary else "bg_card"],
                         fg="#04121f" if primary else THEME["text_main"],
                         activebackground=THEME["border_bright"], disabledforeground="#7392a5",
                         font=("Segoe UI", 9, "bold"), cursor="hand2")

    def _entry(self, parent, variable, **kwargs):
        return tk.Entry(parent, textvariable=variable, bg=THEME["bg_bar"],
                        fg=THEME["text_main"], insertbackground=THEME["text_main"],
                        disabledbackground=THEME["bg_card"], relief="flat",
                        highlightthickness=1, highlightbackground=THEME["bg_card"],
                        highlightcolor=THEME["accent"], font=("Segoe UI", 10), **kwargs)

    def _build(self):
        panel = tk.Frame(self, bg=THEME["bg_panel"], padx=12, pady=10)
        panel.pack(fill="x", padx=12, pady=(12, 6))
        panel.grid_columnconfigure(1, weight=1)
        panel.grid_columnconfigure(3, weight=1)
        self._label(panel, "CHAT WOW", title=True).grid(row=0, column=0, columnspan=4, sticky="ew")
        self._label(panel, "Conecta con un personaje para chatear sin abrir el juego.").grid(
            row=1, column=0, columnspan=4, sticky="ew", pady=(3, 9))
        self._label(panel, "Servidor").grid(row=2, column=0, sticky="w")
        self.host_entry = self._entry(panel, self.host, width=24)
        self.host_entry.grid(row=2, column=1, sticky="ew", padx=(8, 16), ipady=3)
        self._label(panel, "Puerto").grid(row=2, column=2, sticky="w")
        self.port_entry = self._entry(panel, self.port, width=8)
        self.port_entry.grid(row=2, column=3, sticky="w", padx=(8, 0), ipady=3)
        self._label(panel, "Cuenta").grid(row=3, column=0, sticky="w", pady=7)
        self.user_entry = self._entry(panel, self.username, width=16)
        self.user_entry.grid(row=3, column=1, sticky="ew", padx=(8, 16), ipady=3)
        self._label(panel, "Contraseña").grid(row=3, column=2, sticky="w")
        self.password_entry = self._entry(panel, self.password, width=16, show="•")
        self.password_entry.grid(row=3, column=3, sticky="ew", padx=(8, 0), ipady=3)
        self.password_entry.bind("<Return>", lambda _event: self._connect())

        self.saved_check = tk.Checkbutton(
            panel, text=f"Usar cuenta del lanzador: {self.saved_alias}",
            variable=self.use_saved, command=self._sync_login_fields, bg=THEME["bg_panel"],
            activebackground=THEME["bg_panel"], activeforeground=THEME["text_main"],
            fg=THEME["text_main"], selectcolor=THEME["bg_bar"], anchor="w")
        if self.saved_alias:
            self.saved_check.grid(row=4, column=0, columnspan=4, sticky="ew", pady=(0, 6))
        buttons = tk.Frame(panel, bg=THEME["bg_panel"])
        buttons.grid(row=5, column=0, columnspan=4, sticky="ew")
        self.connect_button = self._button(buttons, "Conectar", self._connect, primary=True)
        self.connect_button.pack(side="left")
        self.disconnect_button = self._button(buttons, "Desconectar", self._disconnect)
        self.disconnect_button.pack(side="left", padx=6)
        self._label(buttons, var=self.status).pack(side="left", padx=8, fill="x", expand=True)

        choice = tk.Frame(self, bg=THEME["bg_panel"], padx=12, pady=7)
        choice.pack(fill="x", padx=12, pady=3)
        self.choice_label = self._label(choice, "Reino / personaje")
        self.choice_label.pack(side="left", padx=(0, 10))
        self.choice = ttk.Combobox(choice, textvariable=self.selection, width=24)
        self.choice.pack(side="left", fill="x", expand=True)
        self.choice.bind("<Return>", lambda _event: self._choose())
        self.choose_button = self._button(choice, "Continuar", self._choose)
        self.choose_button.pack(side="right", padx=(8, 0))
        self._set_choice()

        transcript = tk.Frame(self, bg=THEME["bg_panel"])
        transcript.pack(fill="both", expand=True, padx=12, pady=(5, 6))
        self.history = tk.Text(transcript, wrap="word", state="disabled", width=40, height=8,
                               relief="flat", bg=THEME["bg_bar"], fg=THEME["text_main"],
                               font=("Segoe UI", 10), padx=9, pady=7)
        bar = ttk.Scrollbar(transcript, orient="vertical", command=self.history.yview)
        self.history.configure(yscrollcommand=bar.set)
        bar.pack(side="right", fill="y")
        self.history.pack(side="left", fill="both", expand=True)
        for tag, color in {"whisper": "#f0a2f0", "guild": THEME["success"],
                           "system": THEME["text_muted"], "error": "#ffae91"}.items():
            self.history.tag_configure(tag, foreground=color)

        compose = tk.Frame(self, bg=THEME["bg_panel"], padx=8, pady=8)
        compose.pack(fill="x", padx=12, pady=(0, 12))
        compose.grid_columnconfigure(1, weight=1)
        self.mode_box = ttk.Combobox(compose, textvariable=self.mode, values=list(SEND_MODES), width=11)
        self.mode_box.grid(row=0, column=0, sticky="w", padx=(0, 8))
        self.mode_box.bind("<<ComboboxSelected>>", lambda _event: self._sync_compose())
        self.message_entry = self._entry(compose, self.body, width=15)
        self.message_entry.grid(row=0, column=1, sticky="ew", ipady=4)
        self.message_entry.bind("<Return>", self._send)
        self.send_button = self._button(compose, "Enviar", self._send, primary=True)
        self.send_button.grid(row=0, column=2, padx=(8, 0), sticky="e")
        self.target_label = self._label(compose, "Destinatario")
        self.target_label.grid(row=1, column=0, sticky="w", pady=(7, 0))
        self.target_entry = self._entry(compose, self.target)
        self.target_entry.grid(row=1, column=1, sticky="ew", ipady=3, pady=(7, 0))
        self.reply_button = self._button(compose, "Responder", self._reply)
        self.reply_button.grid(row=1, column=2, padx=(8, 0), pady=(7, 0), sticky="e")
        self._sync_login_fields()
        self._sync_compose()

    def _sync_login_fields(self):
        busy = self.session is not None
        self.connect_button.configure(state="disabled" if busy else "normal")
        self.disconnect_button.configure(state="normal" if busy else "disabled")
        self.saved_check.configure(state="disabled" if busy else "normal")
        for w in (self.host_entry, self.port_entry):
            w.configure(state="disabled" if busy else "normal")
        for w in (self.user_entry, self.password_entry):
            w.configure(state="disabled" if busy or self.use_saved.get() else "normal")
        if self.use_saved.get():
            self.password.set("")

    def _sync_compose(self):
        self.mode_box.configure(state="readonly" if self.ready else "disabled")
        for w in (self.message_entry, self.send_button):
            w.configure(state="normal" if self.ready else "disabled")
        self.target_entry.configure(state="normal" if self.ready and self.mode.get() == "Susurro" else "disabled")
        self.reply_button.configure(state="normal" if self.ready and self.last_whisperer else "disabled")

    def _append(self, text, tag="system"):
        clean = str(text).replace("\0", "").replace("\r", "").replace("\n", " ")
        follow = self.history.yview()[1] > .99
        self.history.configure(state="normal")
        self.history.insert("end", f"[{datetime.now():%H:%M}] {clean}\n", tag)
        self.line_count += 1
        if self.line_count > 800:
            self.history.delete("1.0", "2.0")
            self.line_count -= 1
        self.history.configure(state="disabled")
        if follow:
            self.history.see("end")

    def _connect(self):
        if self.session is not None:
            return
        try:
            host, port = validate_endpoint(self.host.get(), self.port.get())
            if self.use_saved.get():
                if (host, port) != (DEFAULT_HOST, DEFAULT_PORT):
                    raise ValueError("Para otro servidor, desmarca la cuenta guardada e introduce sus credenciales.")
                accounts, active = load_accounts()
                if self.saved_alias != active or active not in accounts:
                    raise ValueError("No se pudo cargar la cuenta activa. Vuelve a abrir el chat o inicia sesión manualmente.")
                username, password = accounts[active]
            else:
                username, password = self.username.get(), self.password.get()
            username = username.strip()
            if (not username or not password or len(username.upper().encode("utf-8")) > 255
                    or any(c in username + password for c in "\0\r\n")):
                raise ValueError("Introduce una cuenta y contraseña válidas.")
        except ValueError as exc:
            self._append(str(exc), "error")
            return
        except (ConfigurationError, OSError, TypeError):
            self._append("No se pudo leer la configuración de la cuenta.", "error")
            return

        self.password.set("")
        self.target.set("")
        self.body.set("")
        self.last_whisperer = ""
        self.had_error = False
        self.status.set("Autenticando…")
        self.session = ChatSession(host, port, username, password)
        self._sync_login_fields()
        self.session.start()
        self._poll_session()

    def _set_choice(self, kind=None, choices=()):
        self.choice_kind = kind
        self.choice_label.configure(text={"realm": "Reino", "character": "Personaje"}.get(kind, "Reino / personaje"))
        self.choice.configure(values=choices, state="readonly" if choices else "disabled")
        if choices:
            self.choice.current(0)
        else:
            self.selection.set("")
        self.choose_button.configure(state="normal" if choices else "disabled")

    def _choose(self):
        if self.session is None or self.choice_kind is None or self.choice.current() < 0:
            return
        index = self.choice.current()
        if self.choice_kind == "realm":
            self.session.choose_realm(index)
        else:
            self.session.choose_character(index)
        self._set_choice()

    def _poll_session(self):
        self.poll_job = None
        if self.session is None:
            return
        for _ in range(100):
            try:
                kind, data = self.session.events.get_nowait()
            except queue.Empty:
                break
            if kind == "closed":
                self.session = None
                self.ready = False
                self._set_choice()
                self._sync_login_fields()
                self._sync_compose()
                self.status.set("Desconectado" if not self.had_error else "Desconectado (ver historial)")
                return
            if self.session.stopping.is_set():
                continue
            if kind == "realms":
                self.status.set("Selecciona un reino")
                self._set_choice("realm", data)
            elif kind == "characters":
                self.status.set("Selecciona un personaje")
                self._set_choice("character", [f"{name} (nivel {level})" for name, level in data])
            elif kind == "ready":
                self.ready = True
                self.status.set(f"En línea: {data}")
                self._sync_compose()
                self.message_entry.focus_set()
                self._append(f"Conectado con {data}.")
            elif kind == "status":
                self.status.set(data)
            elif kind == "chat":
                text, tag, sender = data
                self._append(text, tag)
                if sender:
                    self.last_whisperer = sender
                    self._sync_compose()
            else:
                self.had_error |= kind == "error"
                self._append(data, "error" if kind == "error" else "system")
        self.poll_job = self.after(55, self._poll_session)

    def _send(self, _event=None):
        if self.session is not None and self.ready:
            try:
                self.session.send(self.mode.get(), self.body.get(), self.target.get())
            except ValueError as exc:
                self._append(str(exc), "error")
            else:
                self.body.set("")
        return "break"

    def _reply(self):
        if self.ready and self.last_whisperer:
            self.mode.set("Susurro")
            self.target.set(self.last_whisperer)
            self._sync_compose()
            self.message_entry.focus_set()

    def _disconnect(self):
        if self.session is not None:
            self.status.set("Desconectando…")
            self.ready = False
            self._sync_compose()
            self._set_choice()
            self.disconnect_button.configure(state="disabled")
            self.session.stop()

    def close(self):
        if self.poll_job is not None:
            self.after_cancel(self.poll_job)
            self.poll_job = None
        if self.session is not None:
            self.session.stop()
        self.password.set("")
        self.destroy()
