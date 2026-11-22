"""Connect SimpleWoW to a GUI through queues; no Tk calls occur in these threads."""

import queue
import threading
from time import monotonic

from simplewow.definitions import ChatMessageType, Language, LogLevel, is_horde
from simplewow.game import Game
from simplewow.opcodes import WorldCommand
from simplewow.packets import OutPacket
from simplewow.ui import GameUI


SEND_MODES = {
    "Decir": ChatMessageType.Say,
    "Gritar": ChatMessageType.Yell,
    "Hermandad": ChatMessageType.Guild,
    "Oficiales": ChatMessageType.Officer,
    "Susurro": ChatMessageType.Whisper,
}
LABELS = {
    ChatMessageType.System: "Sistema",
    ChatMessageType.WhisperInform: "Susurro a",
    ChatMessageType.Party: "Grupo",
    ChatMessageType.PartyLeader: "Líder de grupo",
    ChatMessageType.Raid: "Banda",
    ChatMessageType.RaidLeader: "Líder de banda",
    ChatMessageType.Yell: "Gritar",
    **{kind: label for label, kind in SEND_MODES.items()},
}
NOTICES = {
    "Authentication succeeded!": "Cuenta autenticada.",
    "Wrong password or invalid account or authentication error": "Cuenta o contraseña incorrectas.",
    "Wrong build number": "El servidor no admite la versión 3.3.5a (12340).",
    "Unknown account name": "El servidor no reconoce esa cuenta.",
    "Account already logged in": "Esta cuenta ya está conectada.",
    "The realm list is empty.": "El servidor no devolvió ningún reino.",
    "Server has closed the connection": "El servidor cerró la conexión.",
    "Server has disconnected.": "El servidor cerró la conexión.",
    "Server auth failed!": "No se pudo verificar la autenticación del servidor.",
    "This account requires extra security (PIN/matrix/authenticator), which is not supported.":
        "La cuenta requiere PIN o autenticador. El chat de SimpleWoW no admite ese método.",
}


class ChatSession(GameUI):
    """A single, explicitly started chat connection."""

    def __init__(self, host, port, username, password):
        self.events = queue.Queue()
        self.actions = queue.Queue()
        self.stopping = threading.Event()
        self.game = Game(lambda: self, host, port, username, password, LogLevel.Info)
        self.thread = threading.Thread(target=self._run, name="launcher-chat", daemon=True)
        self.realms = ()
        self.characters = ()
        self.phase = "auth"
        self.deadline = None

    def start(self):
        self.thread.start()

    def _run(self):
        try:
            self.game.start()
        except Exception:
            # Do not send exception/connection objects containing credentials to Tk or a log.
            self._emit("error", "No se pudo completar la sesión de chat.")
        finally:
            self.events.put(("closed", None))

    def stop(self):
        self.stopping.set()
        self.game.cancel()

    def choose_realm(self, index):
        self.actions.put(("realm", index))

    def choose_character(self, index):
        self.actions.put(("character", index))

    def send(self, mode, message, target=""):
        message, target = message.strip(), target.strip()
        if mode not in SEND_MODES:
            raise ValueError("Selecciona un tipo de mensaje.")
        if not message or len(message.encode("utf-8")) > 255 or any(c in message for c in "\r\n\0"):
            raise ValueError("Escribe un mensaje de una línea (máximo 255 bytes).")
        if mode == "Susurro" and (not target or len(target.encode("utf-8")) > 64
                                  or any(c.isspace() or c == "\0" for c in target)):
            raise ValueError("Escribe un nombre de destinatario válido.")
        self.actions.put(("send", (mode, message, target)))

    def update(self):
        if self.deadline is not None and monotonic() >= self.deadline:
            self._emit("error", "El servidor no respondió a tiempo. Vuelve a conectar.")
            self.game.exit()
            return
        try:
            kind, payload = self.actions.get(timeout=.1)
        except queue.Empty:
            return
        if self.stopping.is_set():
            return
        try:
            self._handle_action(kind, payload)
        except OSError:
            self._emit("error", "Se perdió la conexión con el servidor.")
            self.game.exit()

    def _handle_action(self, kind, payload):
        if kind == "realm" and self.phase == "realm" and 0 <= payload < len(self.realms):
            self.phase = "world"
            self._emit("status", f"Conectando con {self.realms[payload].name}…")
            self.game.connect_to(self.realms[payload])
            self.deadline = monotonic() + 30
        elif kind == "characters" and self.phase == "world":
            self.deadline = None
            if payload:
                self.characters = payload
                self.phase = "character"
                self._emit("characters", [(c.name, c.level) for c in payload])
            else:
                self._emit("error", "No hay personajes en este reino.")
                self.game.exit()
        elif kind == "character" and self.phase == "character" and 0 <= payload < len(self.characters):
            char = self.characters[payload]
            self.phase = "entering"
            self.deadline = monotonic() + 30
            self.game.world.selected_character = char
            self._emit("status", f"Entrando con {char.name}…")
            packet = OutPacket(WorldCommand.CMSG_PLAYER_LOGIN)
            packet.write_u64(char.guid)
            self.game.send_packet(packet)
        elif kind == "ready" and self.phase == "entering":
            self.deadline = None
            self.phase = "ready"
            self._emit("ready", self.game.world.selected_character.name)
        elif kind == "login_failed" and self.phase == "entering":
            self._emit("error", f"El servidor rechazó la entrada del personaje (código {payload}).")
            self.game.exit()
        elif kind == "send" and self.phase == "ready":
            mode, body, target = payload
            char = self.game.world.selected_character
            packet = OutPacket(WorldCommand.CMSG_MESSAGECHAT)
            packet.write_u32(SEND_MODES[mode])
            packet.write_u32(Language.Orcish if is_horde(char.race) else Language.Common)
            if mode == "Susurro":
                packet.write_cstring(target)
            packet.write_cstring(body)
            self.game.send_packet(packet)
        elif kind == "send":
            self._emit("error", "El personaje todavía no ha entrado en el mundo.")

    def _emit(self, kind, payload):
        if not self.stopping.is_set():
            self.events.put((kind, payload))

    def present_realm_list(self, realm_list):
        self.realms = tuple(realm_list)
        self.phase = "realm"
        self._emit("realms", [server.name for server in self.realms])

    def present_character_list(self, characters):
        self.actions.put(("characters", characters))

    def no_characters(self):
        self.present_character_list([])

    def world_entered(self):
        self.actions.put(("ready", None))

    def character_login_failed(self, result):
        self.actions.put(("login_failed", result))

    def present_chat_message(self, message):
        if message.language == Language.Addon:
            return
        kind = message.sender.type
        label = message.sender.channel_name if kind == ChatMessageType.Channel else LABELS.get(kind, kind.name)
        sender = message.sender.sender
        prefix = f"[{label}] {sender}: " if sender else f"[{label}] "
        reply_to = sender if kind == ChatMessageType.Whisper else ""
        tone = "whisper" if kind in (ChatMessageType.Whisper, ChatMessageType.WhisperInform) else \
            ("guild" if kind in (ChatMessageType.Guild, ChatMessageType.Officer) else "chat")
        self._emit("chat", (prefix + message.message, tone, reply_to))

    def log(self, message, level=LogLevel.Info):
        # The terminal client uses partial lines for progress; the GUI has its own.
        pass

    def log_line(self, message="", level=LogLevel.Info):
        rendered = NOTICES.get(message, message)
        if level >= LogLevel.Error:
            self._emit("error", rendered)
        elif level >= LogLevel.Info and message and message not in ("done!", "No characters found!"):
            self._emit("notice", rendered)

    def log_exception(self, message):
        raise RuntimeError(message)

    def read_line(self):
        raise EOFError

    def read_key(self, timeout=None):
        return None

    def exit(self):
        pass
