"""Command-line UI (port of CLIClient/UI/CommandLine/*).

Key bindings (same as the C# client, once a character is logged in):
    S say   Y yell   G guild   O officer   W whisper   R reply to a whisperer
"""
from __future__ import annotations

import os
import sys
import threading
import time
import traceback
from datetime import datetime
from typing import Callable, Dict, List, Optional

from .auth import WorldServerList
from .character import Character
from .chat import ChatMessage
from .definitions import (
    ChatMessageType, ChatTag, Language, LogLevel, enum_name, is_horde, PlayerClass, Race,
)
from .opcodes import WorldCommand
from .packets import OutPacket
from .ui import GameUI

# ANSI foreground colours standing in for System.ConsoleColor.
_DARK_YELLOW, _YELLOW, _MAGENTA, _DARK_RED, _RED = "33", "93", "95", "31", "91"
_DARK_CYAN, _CYAN, _GREEN, _DARK_GREEN, _WHITE = "36", "96", "92", "32", "97"

_CHAT_COLORS = {
    ChatMessageType.Channel: _DARK_YELLOW,
    ChatMessageType.Whisper: _MAGENTA,
    ChatMessageType.WhisperInform: _MAGENTA,
    ChatMessageType.WhisperForeign: _MAGENTA,
    ChatMessageType.System: _YELLOW,
    ChatMessageType.Money: _YELLOW,
    ChatMessageType.TargetIcons: _YELLOW,
    ChatMessageType.Achievement: _YELLOW,
    ChatMessageType.Emote: _DARK_RED,
    ChatMessageType.TextEmote: _DARK_RED,
    ChatMessageType.MonsterEmote: _DARK_RED,
    ChatMessageType.Party: _DARK_CYAN,
    ChatMessageType.PartyLeader: _CYAN,
    ChatMessageType.Raid: _RED,
    ChatMessageType.RaidLeader: _RED,
    ChatMessageType.RaidWarning: _RED,
    ChatMessageType.Guild: _GREEN,
    ChatMessageType.GuildAchievement: _GREEN,
    ChatMessageType.Officer: _DARK_GREEN,
    ChatMessageType.Yell: _DARK_RED,
}


class _Terminal:
    """Single-key input with a timeout, on POSIX ttys, Windows consoles and plain pipes."""

    def __init__(self) -> None:
        self._tty = sys.stdin.isatty()
        self._saved = None
        self._lock = threading.Lock()

    def enter_cbreak(self) -> None:
        if os.name == "nt" or not self._tty:
            return
        import termios
        import tty
        with self._lock:
            if self._saved is None:
                fd = sys.stdin.fileno()
                self._saved = termios.tcgetattr(fd)
                tty.setcbreak(fd)

    def restore(self) -> None:
        if os.name == "nt" or self._saved is None:
            return
        import termios
        with self._lock:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, self._saved)
            self._saved = None

    def read_key(self, timeout: Optional[float]) -> Optional[str]:
        if not self._tty:
            # Piped input: one line per "key press" (first character), blocking.
            line = sys.stdin.readline()
            if line == "":
                raise EOFError
            return line[0]
        if os.name == "nt":
            import msvcrt
            end = None if timeout is None else time.monotonic() + timeout
            while True:
                if msvcrt.kbhit():
                    return msvcrt.getwch()
                if end is not None and time.monotonic() >= end:
                    return None
                time.sleep(0.01)
        import select
        self.enter_cbreak()
        fd = sys.stdin.fileno()
        ready, _, _ = select.select([fd], [], [], timeout)
        if not ready:
            return None
        data = os.read(fd, 1)
        if not data:
            raise EOFError
        return data.decode("utf-8", errors="ignore")


class CommandLineUI(GameUI):
    def __init__(self) -> None:
        self.log_level = LogLevel.Info
        self._lock = threading.RLock()
        self._term = _Terminal()
        self._color = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
        if os.name == "nt":
            os.system("")  # enables ANSI escape processing on Windows 10+ consoles
        self._log_file = open(
            datetime.now().strftime("%Y-%m-%d %H-%M-%S") + ".log", "w", encoding="utf-8", buffering=1
        )
        self._keybinds: Dict[str, Callable[[], None]] = {
            "s": self.do_say_chat,
            "y": self.do_yell_chat,
            "g": self.do_guild_chat,
            "o": self.do_officer_chat,
            "w": self.do_whisper,
            "r": self.do_whisper_reply,
        }

    # -- main loop hooks ---------------------------------------------------------------------

    def update(self) -> None:
        if self.game.world.selected_character is None:
            time.sleep(0.1)
            return
        try:
            key = self._term.read_key(0.1)
            handler = self._keybinds.get(key.lower()) if key else None
            if handler:
                handler()
        except (EOFError, KeyboardInterrupt):
            self.game.exit()

    def exit(self) -> None:
        self._term.restore()
        if sys.stdin.isatty() and not getattr(self.game, "interrupted", False):
            self.log("Press any key to continue...")
            try:
                self._term.read_key(None)
            except EOFError:
                pass
            self._term.restore()
        self._log_file.close()

    # -- presenters ----------------------------------------------------------------------------

    def present_realm_list(self, realm_list: WorldServerList) -> None:
        if realm_list.count == 1:
            selected = realm_list[0]
        else:
            self.log_line("\n\tName\tType\tPopulation")
            for index, server in enumerate(realm_list):
                self.log_line(f"{index}\t{server.name}\t{server.type}\t{server.population}")
            index = self._ask_index("Choose a realm:  ", realm_list.count)
            if index is None:
                return
            selected = realm_list[index]
        self.game.connect_to(selected)

    def present_character_list(self, characters: List[Character]) -> None:
        self.log_line("\n\tName\tLevel Race Class")
        for index, c in enumerate(characters):
            self.log_line(
                f"{index}\t{c.name}\t{c.level} {enum_name(Race, c.race)} {enum_name(PlayerClass, c.player_class)}"
            )
        if len(characters) < 10:
            self.log_line(f"{len(characters)}\tCreate a new character. (NOT YET IMPLEMENTED)")

        while True:
            limit = len(characters) + (1 if len(characters) < 10 else 0)
            index = self._ask_index("Choose a character:  ", limit)
            if index is None:
                return
            if index < len(characters):
                break
            self.log_line("Character creation is not implemented yet.")

        character = characters[index]
        self.log_line(f"Entering pseudo-world with character {character.name}")
        packet = OutPacket(WorldCommand.CMSG_PLAYER_LOGIN)
        packet.write_u64(character.guid)
        self.game.send_packet(packet)
        # Set last: the main loop starts reading key presses as soon as this is non-None.
        self.game.world.selected_character = character

    def present_chat_message(self, message: ChatMessage) -> None:
        chat_type = message.sender.type
        text = "To: " if chat_type == ChatMessageType.WhisperInform else chat_type.name
        if chat_type == ChatMessageType.Channel:
            text += f" [{message.sender.channel_name}] "
        elif chat_type == ChatMessageType.Whisper:
            self.game.world.last_whisperers.append(message.sender.sender)
        text += "["
        if message.chat_tag & ChatTag.Gm:
            text += "<GM>"
        if message.chat_tag & ChatTag.Afk:
            text += "<AFK>"
        if message.chat_tag & ChatTag.Dnd:
            text += "<DND>"
        text += f"{message.sender.sender}]: {message.message}"
        level = LogLevel.Debug if message.language == Language.Addon else LogLevel.Info
        self.log_line(text, level, _CHAT_COLORS.get(chat_type, _WHITE))

    # -- output ------------------------------------------------------------------------------

    def _emit(self, message: str, newline: bool, level: LogLevel, color: Optional[str]) -> None:
        with self._lock:
            if level < self.log_level:
                return
            shown = f"\x1b[{color}m{message}\x1b[0m" if (color and self._color) else message
            sys.stdout.write(shown + ("\n" if newline else ""))
            sys.stdout.flush()
            self._log_file.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} : {message}" + ("\n" if newline else ""))

    def log(self, message: str, level: LogLevel = LogLevel.Info, color: Optional[str] = None) -> None:
        self._emit(message, False, level, color)

    def log_line(self, message: str = "", level: LogLevel = LogLevel.Info, color: Optional[str] = None) -> None:
        self._emit(message, True, level, color)

    def log_exception(self, message: str) -> None:
        self._log_file.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} : Exception: {message}\n")
        self._log_file.write("".join(traceback.format_stack()) + "\n")
        raise Exception(message)

    # -- input -------------------------------------------------------------------------------

    def read_line(self) -> str:
        # We don't want to clutter the console, so hold output back while waiting for input.
        with self._lock:
            self._term.restore()
            try:
                return input()
            finally:
                self._term.enter_cbreak()

    def read_key(self, timeout: Optional[float] = None) -> Optional[str]:
        return self._term.read_key(timeout)

    def _ask_index(self, prompt: str, count: int) -> Optional[int]:
        """Ask for a number in [0, count). Returns None if input ends."""
        while True:
            self.log(prompt)
            try:
                line = self.read_line()
            except EOFError:
                self.game.exit()
                return None
            try:
                index = int(line)
            except ValueError:
                self.log_line()
                continue
            if 0 <= index < count:
                return index

    # -- key bindings (KeyBindHandlers/*.cs) ----------------------------------------------------

    def _send_chat(self, chat_type: ChatMessageType, message: str, target: Optional[str] = None) -> None:
        packet = OutPacket(WorldCommand.CMSG_MESSAGECHAT)
        packet.write_u32(chat_type)
        race = self.game.world.selected_character.race
        packet.write_u32(Language.Orcish if is_horde(race) else Language.Common)
        if target is not None:
            packet.write_cstring(target)
        packet.write_cstring(message)
        self.game.send_packet(packet)

    def do_say_chat(self) -> None:
        self.log("Say: ")
        self._send_chat(ChatMessageType.Say, self.read_line())

    def do_yell_chat(self) -> None:
        self.log("Yell: ")
        self._send_chat(ChatMessageType.Yell, self.read_line())

    def do_guild_chat(self) -> None:
        self.log("Guild Message: ")
        self._send_chat(ChatMessageType.Guild, self.read_line())

    def do_officer_chat(self) -> None:
        self.log("Officer Message: ")
        self._send_chat(ChatMessageType.Officer, self.read_line())

    def do_whisper(self) -> None:
        self.log_line("Enter name of player to whisper, or enter 'Q' to go back.", LogLevel.Detail)
        self.log("To: ")
        target = self.read_line()
        if target == "Q":
            return
        self.log("Message: ")
        # The server answers with a WhisperInform message, which is what gets printed.
        self._send_chat(ChatMessageType.Whisper, self.read_line(), target)

    def do_whisper_reply(self) -> None:
        whisperers = self.game.world.last_whisperers
        if not whisperers:
            return
        target = whisperers[0]
        self.log_line(
            "Hit <TAB> to cycle through last whisperers, hit <ENTER> to select current recipient, "
            "hit <ESCAPE> to return.", LogLevel.Detail)
        self.log_line(f"To: {target}")
        while True:
            key = self.read_key(None)
            if key in ("\r", "\n"):
                break
            if key == "\t":
                whisperers.rotate(-1)
                previous, target = target, whisperers[0]
                if target != previous:
                    self.log_line(f"To: {target}")
            elif key == "\x1b":
                return
        self.log("Message: ")
        self._send_chat(ChatMessageType.Whisper, self.read_line(), target)
