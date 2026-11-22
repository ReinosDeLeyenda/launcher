"""Chat models (port of Client/Chat/ChatChannel.cs and ChatMessage.cs)."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from .definitions import ChatMessageType, ChatTag


@dataclass
class ChatChannel:
    """A channel through which a message is sent. This can also be a whisper."""

    type: ChatMessageType = ChatMessageType.System
    sender: str = ""
    channel_name: str = ""  # optional


@dataclass
class ChatMessage:
    sender: ChatChannel = field(default_factory=ChatChannel)
    language: int = 0
    chat_tag: ChatTag = ChatTag.NONE
    message: str = ""
