"""Game orchestration (port of Client/Game.cs and Client/World.cs)."""
from __future__ import annotations

from collections import deque
from threading import Event
from typing import Callable, Deque, Dict, Optional

from .auth import AuthSocket, WorldServerInfo
from .character import Character
from .chat import ChatMessage
from .definitions import LogLevel
from .packets import OutPacket
from .ui import GameUI
from .world_socket import WorldSocket


class GameWorld:
    """Stores world variables."""

    def __init__(self) -> None:
        # Player name lookup per GUID - through CMSG/SMSG_NAME_QUERY(_RESPONSE)
        self.player_name_lookup: Dict[int, str] = {}
        # Message queue for when the sender's name hasn't been queried yet
        self.queued_chat_messages: Dict[int, Deque[ChatMessage]] = {}
        # Character currently logged into the world
        self.selected_character: Optional[Character] = None
        # People who last whispered the client
        self.last_whisperers: Deque[str] = deque()


class Game:
    def __init__(
        self,
        ui_class: Callable[[], GameUI],
        hostname: str,
        port: int,
        username: str,
        password: str,
        log_level: LogLevel,
    ) -> None:
        self.ui = ui_class()
        self.ui.game = self
        self.ui.log_level = log_level

        self.world = GameWorld()
        self.username = username
        self.key: bytes = b""  # 40-byte session key from the realm server

        self.running = False
        self.interrupted = False
        self._cancelled = Event()
        self._auth = AuthSocket(self, hostname, port, username, password)
        self._world_socket: Optional[WorldSocket] = None

    def connect_to(self, server: WorldServerInfo) -> None:
        if self._cancelled.is_set():
            return
        self.key = self._auth.key
        self._auth.close()

        self._world_socket = WorldSocket(self, server)
        if not self._cancelled.is_set() and self._world_socket.connect() and not self._cancelled.is_set():
            self._world_socket.start()
        else:
            self.exit()

    def start(self) -> None:
        try:
            try:
                realms = None if self._cancelled.is_set() else self._auth.authenticate()
            finally:
                self._auth.password = ""
            if self._cancelled.is_set():
                return
            self.running = realms is not None
            if realms is not None:
                if len(realms) == 0:
                    self.ui.log_line("The realm list is empty.", LogLevel.Error)
                    self.running = False
                else:
                    self.ui.present_realm_list(realms)
            while self.running and not self._cancelled.is_set():
                self.ui.update()
        except KeyboardInterrupt:
            self.interrupted = True
        finally:
            self.running = False
            if self._world_socket is not None:
                self._world_socket.close()
            self._auth.close()
            self.ui.exit()

    def exit(self) -> None:
        self.running = False

    def cancel(self) -> None:
        """Request exit and unblock any socket reads without waiting for a thread."""
        self._cancelled.set()
        self.exit()
        self._auth.close()
        if self._world_socket is not None:
            self._world_socket.close()

    def send_packet(self, packet: OutPacket) -> None:
        if self._world_socket is not None:
            self._world_socket.send(packet)
