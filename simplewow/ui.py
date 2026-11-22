"""UI interface (port of Client/UI/IGameUI.cs)."""
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, List, Optional

from .definitions import LogLevel

if TYPE_CHECKING:  # pragma: no cover
    from .auth import WorldServerList
    from .character import Character
    from .chat import ChatMessage
    from .game import Game


class GameUI(ABC):
    game: "Game"
    log_level: LogLevel = LogLevel.Info

    @abstractmethod
    def update(self) -> None:
        """Called repeatedly from the main loop."""

    @abstractmethod
    def exit(self) -> None: ...

    # -- packet handler presenters -----------------------------------------------------

    @abstractmethod
    def present_realm_list(self, realm_list: "WorldServerList") -> None: ...

    @abstractmethod
    def present_character_list(self, characters: "List[Character]") -> None: ...

    @abstractmethod
    def present_chat_message(self, message: "ChatMessage") -> None: ...

    def world_entered(self) -> None:
        """Optional notification after the server confirms character login."""

    def no_characters(self) -> None:
        """Optional notification after an empty character list."""

    def character_login_failed(self, result: int) -> None:
        self.log_line(f"Character login failed ({result}).", LogLevel.Error)

    # -- output --------------------------------------------------------------------------

    @abstractmethod
    def log(self, message: str, level: LogLevel = LogLevel.Info) -> None: ...

    @abstractmethod
    def log_line(self, message: str = "", level: LogLevel = LogLevel.Info) -> None: ...

    @abstractmethod
    def log_exception(self, message: str) -> None: ...

    # -- input ---------------------------------------------------------------------------

    @abstractmethod
    def read_line(self) -> str: ...

    @abstractmethod
    def read_key(self, timeout: Optional[float] = None) -> Optional[str]: ...
