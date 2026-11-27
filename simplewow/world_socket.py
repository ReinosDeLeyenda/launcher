"""World server connection (port of World/Network/WorldSocket.cs and PacketHandlers/*).

Threading model: one reader thread parses the (encrypted) packet stream and a second
worker thread runs the packet handlers in order, so a handler that blocks on user
input (character selection) never stalls reading. The C# version used the thread
pool for the same purpose, which did not preserve packet order.
"""
from __future__ import annotations

import os
import queue
import socket
import struct
import threading
import time
import traceback
from collections import deque
from enum import IntEnum
from typing import TYPE_CHECKING, Callable, Dict, Optional

from .auth import CLIENT_BUILD, WorldServerInfo
from .character import Character
from .chat import ChatChannel, ChatMessage
from .crypto import AuthenticationCrypto, AuthStatus, sha1
from .definitions import ChatMessageType, ChatTag, LogLevel
from .opcodes import WorldCommand
from .packets import InPacket, OutPacket
from .util import recv_exact

if TYPE_CHECKING:  # pragma: no cover
    from .game import Game


class CommandDetail(IntEnum):
    AuthSuccess = 0x0C
    AuthQueue = 0x0D
    AuthFailure = 0x0E


# Chat types that SMSG_MESSAGECHAT handling displays (same list as the C# switch).
_DISPLAYED_CHAT_TYPES = {
    ChatMessageType.Say, ChatMessageType.Yell, ChatMessageType.Party, ChatMessageType.PartyLeader,
    ChatMessageType.Raid, ChatMessageType.RaidLeader, ChatMessageType.RaidWarning,
    ChatMessageType.Guild, ChatMessageType.Officer, ChatMessageType.Emote, ChatMessageType.TextEmote,
    ChatMessageType.Whisper, ChatMessageType.WhisperInform, ChatMessageType.System,
    ChatMessageType.Channel, ChatMessageType.Battleground, ChatMessageType.BattlegroundNeutral,
    ChatMessageType.BattlegroundAlliance, ChatMessageType.BattlegroundHorde,
    ChatMessageType.BattlegroundLeader, ChatMessageType.Achievement, ChatMessageType.GuildAchievement,
}

# Packets the CLI deliberately ignores (CLIClient/UI/CommandLine/PacketHandlers/DummyHandler.cs).
IGNORED_COMMANDS = frozenset({
    WorldCommand.SMSG_POWER_UPDATE, WorldCommand.SMSG_SET_PROFICIENCY,
    WorldCommand.MSG_SET_DUNGEON_DIFFICULTY,
    WorldCommand.SMSG_ACCOUNT_DATA_TIMES, WorldCommand.SMSG_FEATURE_SYSTEM_STATUS,
    WorldCommand.SMSG_LEARNED_DANCE_MOVES, WorldCommand.SMSG_BINDPOINTUPDATE,
    WorldCommand.SMSG_TALENTS_INFO, WorldCommand.SMSG_INSTANCE_DIFFICULTY,
    WorldCommand.SMSG_INITIAL_SPELLS, WorldCommand.SMSG_SEND_UNLEARN_SPELLS,
    WorldCommand.SMSG_ACTION_BUTTONS, WorldCommand.SMSG_INITIALIZE_FACTIONS,
    WorldCommand.SMSG_ALL_ACHIEVEMENT_DATA, WorldCommand.SMSG_EQUIPMENT_SET_LIST,
    WorldCommand.SMSG_LOGIN_SETTIMESPEED, WorldCommand.SMSG_SET_FORCED_REACTIONS,
    WorldCommand.SMSG_COMPRESSED_UPDATE_OBJECT, WorldCommand.SMSG_MONSTER_MOVE,
    WorldCommand.SMSG_PONG,
})


class WorldSocket:
    def __init__(self, game: "Game", server_info: WorldServerInfo) -> None:
        self.game = game
        self.server_info = server_info
        self.crypto = AuthenticationCrypto()
        self.transferred = 0
        self.sent = 0
        self.received = 0

        self._sock: Optional[socket.socket] = None
        self._send_lock = threading.Lock()
        self._closing = False
        self._queue: "queue.Queue[Optional[tuple]]" = queue.Queue()
        self._start_time = time.monotonic()
        self._ping_seq = 0
        self._handlers: Dict[int, Callable[[InPacket], None]] = {}
        self.init_handlers()

    @property
    def _ui(self):
        return self.game.ui

    # -- handler registration ---------------------------------------------------------

    def init_handlers(self) -> None:
        self._handlers = {
            WorldCommand.ServerAuthChallenge: self.handle_server_auth_challenge,
            WorldCommand.ServerAuthResponse: self.handle_server_auth_response,
            WorldCommand.ServerCharacterEnumeration: self.handle_char_enum,
            WorldCommand.SMSG_LOGIN_VERIFY_WORLD: lambda _packet: self._ui.world_entered(),
            WorldCommand.SMSG_CHARACTER_LOGIN_FAILED: self.handle_character_login_failed,
            WorldCommand.SMSG_MESSAGECHAT: self.handle_message_chat,
            WorldCommand.SMSG_CHAT_PLAYER_NOT_FOUND: self.handle_chat_player_not_found,
            WorldCommand.SMSG_NAME_QUERY_RESPONSE: self.handle_name_query_response,
            WorldCommand.SMSG_TIME_SYNC_REQ: self.handle_time_sync_req,
        }
        for name, handler in self._handlers.items():
            self._ui.log_line(f"Registered '{handler.__name__}' to '{WorldCommand(name).name}'", LogLevel.Debug)

    # -- connection -------------------------------------------------------------------

    def connect(self) -> bool:
        if self._closing:
            return False
        info = self.server_info
        self._ui.log(f"Connecting to realm {info.name}... ")
        try:
            addr_info = socket.getaddrinfo(info.address, info.port, socket.AF_INET, socket.SOCK_STREAM)
            self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._sock.settimeout(15)
            self._sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            self._sock.connect(addr_info[0][4])
            if self._closing:
                self.close()
                return False
            self._sock.settimeout(None)
        except OSError as ex:
            self._ui.log_line(f"failed. ({ex})", LogLevel.Error)
            return False
        self._ui.log_line("done!")
        return True

    def start(self) -> None:
        threading.Thread(target=self._worker_loop, name="world-handlers", daemon=True).start()
        threading.Thread(target=self._read_loop, name="world-reader", daemon=True).start()
        threading.Thread(target=self._ping_loop, name="world-ping", daemon=True).start()

    def close(self) -> None:
        self._closing = True
        self._queue.put(None)
        if self._sock is not None:
            try:
                self._sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            self._sock.close()

    # -- sending ----------------------------------------------------------------------

    def send(self, packet: OutPacket) -> None:
        # Encrypt and send under one lock: RC4 is a stream, so order on the wire must
        # equal order of encryption (the C# version encrypted outside its lock).
        with self._send_lock:
            data = packet.build(self.crypto)
            self._sock.sendall(data)
        self.transferred += len(data)
        self.sent += len(data)

    # -- receiving --------------------------------------------------------------------

    def _read_header(self):
        """Server header: 2-byte big-endian size (3 bytes if the top bit of the first
        byte is set), then a 2-byte little-endian opcode. Size includes the opcode."""
        first = self.crypto.decrypt(recv_exact(self._sock, 1))[0]
        if first & 0x80:
            rest = self.crypto.decrypt(recv_exact(self._sock, 4))
            size = ((first & 0x7F) << 16) | (rest[0] << 8) | rest[1]
            (command,) = struct.unpack_from("<H", rest, 2)
            consumed = 5
        else:
            rest = self.crypto.decrypt(recv_exact(self._sock, 3))
            size = (first << 8) | rest[0]
            (command,) = struct.unpack_from("<H", rest, 1)
            consumed = 4
        self.transferred += consumed
        self.received += consumed
        return command, size - 2

    def _read_loop(self) -> None:
        try:
            while True:
                command, length = self._read_header()
                payload = recv_exact(self._sock, length) if length > 0 else b""
                self.transferred += length
                self.received += length
                self._ui.log_line(f"Command {command} Packet Size {length}", LogLevel.Debug)
                self._dispatch(InPacket(command, payload))
        except (ConnectionError, OSError, EOFError):
            if not self._closing:
                self._ui.log_line("Server has closed the connection")
                self.game.exit()

    def _dispatch(self, packet: InPacket) -> None:
        handler = self._handlers.get(packet.command)
        if handler is None:
            if packet.command not in IGNORED_COMMANDS:
                self._ui.log_line(f"Unknown or unhandled command '{packet.command}'", LogLevel.Debug)
            return
        self._ui.log_line(f"Received {packet.command}", LogLevel.Debug)
        if self.crypto.status == AuthStatus.Ready:
            self._queue.put((handler, packet))  # handled asynchronously, in order
        else:
            handler(packet)  # the auth challenge must be handled before the next read

    def _worker_loop(self) -> None:
        while True:
            item = self._queue.get()
            if item is None:
                return
            handler, packet = item
            try:
                handler(packet)
            except Exception as ex:  # keep the client alive if one packet is malformed
                self._ui.log_line(f"Error handling command {packet.command}: {ex!r}", LogLevel.Error)
                self._ui.log_line(traceback.format_exc(), LogLevel.Debug)

    # -- auth handlers (PacketHandlers/AuthHandlers.cs) ------------------------------------

    def _uptime_ms(self) -> int:
        return int((time.monotonic() - self._start_time) * 1000) & 0xFFFFFFFF

    def _ping_loop(self) -> None:
        while not self._closing:
            time.sleep(30)
            if self._closing or self.crypto.status != AuthStatus.Ready:
                continue
            self._ping_seq = (self._ping_seq + 1) & 0xFFFFFFFF
            pkt = OutPacket(WorldCommand.CMSG_PING)
            pkt.write_u32(self._ping_seq)
            pkt.write_u32(0)  # latencia estimada en ms
            try:
                self.send(pkt)
            except OSError:
                break

    def handle_time_sync_req(self, packet: InPacket) -> None:
        counter = packet.read_u32()
        resp = OutPacket(WorldCommand.CMSG_TIME_SYNC_RESP)
        resp.write_u32(counter)
        resp.write_u32(self._uptime_ms())
        self.send(resp)

    def handle_server_auth_challenge(self, packet: InPacket) -> None:
        packet.read_u32()               # one
        seed = packet.read_u32()        # server seed (remaining 32 bytes are unused)
        our_seed = int.from_bytes(os.urandom(4), "little")
        username = self.game.username.upper()

        digest = sha1(
            username.encode("utf-8"),
            struct.pack("<I", 0),
            struct.pack("<I", our_seed),
            struct.pack("<I", seed),
            self.game.key,
        )

        response = OutPacket(WorldCommand.ClientAuthSession)
        response.write_u32(CLIENT_BUILD)
        response.write_u32(0)                       # login server id
        response.write_cstring(username)
        response.write_u32(0)                       # login server type
        response.write_u32(our_seed)
        response.write_u32(0)                       # region id
        response.write_u32(0)                       # battlegroup id
        response.write_u32(self.server_info.realm_id)
        response.write_u64(0)
        response.write_bytes(digest)
        response.write_u32(0)                       # length of addon data
        self.send(response)

        # Everything after the auth session is encrypted. The C# TODO applies here too:
        # a failed auth is only noticed from the (then encrypted) response header.
        self.crypto.initialize(self.game.key)

    def handle_server_auth_response(self, packet: InPacket) -> None:
        detail = packet.read_u8()
        if detail == CommandDetail.AuthSuccess:
            # followed by billing time/flags/rested time/expansion - not needed here
            self.send(OutPacket(WorldCommand.ClientEnumerateCharacters))
        else:
            try:
                label = CommandDetail(detail).name
            except ValueError:
                label = f"0x{detail:02X}"
            self._ui.log_line(f"Authentication succeeded, but received response {label}")
            self.game.exit()

    def handle_char_enum(self, packet: InPacket) -> None:
        count = packet.read_u8()
        if count == 0:
            self._ui.log_line("No characters found!")
            self._ui.no_characters()
            return
        self._ui.present_character_list([Character(packet) for _ in range(count)])

    def handle_character_login_failed(self, packet: InPacket) -> None:
        self._ui.character_login_failed(packet.read_u8())

    # -- chat handlers (PacketHandlers/ChatHandlers.cs) ----------------------------------

    def handle_message_chat(self, packet: InPacket) -> None:
        raw_type = packet.read_u8()
        language = packet.read_u32()
        sender_guid = packet.read_u64()
        packet.read_i32()  # flags / unknown
        try:
            chat_type = ChatMessageType(raw_type)
        except ValueError:
            return
        if chat_type not in _DISPLAYED_CHAT_TYPES:
            return

        channel = ChatChannel(type=chat_type)
        if chat_type == ChatMessageType.Channel:
            channel.channel_name = packet.read_cstring()
        packet.read_u64()   # receiver guid (the C# code treated this as the sender)
        packet.read_i32()   # text length
        message = ChatMessage(sender=channel, language=language)
        message.message = packet.read_cstring()
        message.chat_tag = ChatTag(packet.read_u8())

        world = self.game.world
        # System messages have no sender; otherwise use the cached name if we have one
        if chat_type == ChatMessageType.System:
            message.sender.sender = ""
            self._ui.present_chat_message(message)
            return
        name = world.player_name_lookup.get(sender_guid)
        if name is not None:
            message.sender.sender = name
            self._ui.present_chat_message(message)
            return

        # Unknown sender: park the message and ask the server for the name.
        world.queued_chat_messages.setdefault(sender_guid, deque()).append(message)
        query = OutPacket(WorldCommand.CMSG_NAME_QUERY)
        query.write_u64(sender_guid)
        self.game.send_packet(query)
        # queued chat is printed when SMSG_NAME_QUERY_RESPONSE arrives

    def handle_chat_player_not_found(self, packet: InPacket) -> None:
        self._ui.log_line(f"Player {packet.read_cstring()} not found!")

    # -- query handler (PacketHandlers/QueryHandler.cs) -----------------------------------

    def handle_name_query_response(self, packet: InPacket) -> None:
        guid = packet.read_packed_guid()
        not_found = packet.read_bool()
        if not_found:
            return
        name = packet.read_cstring()

        world = self.game.world
        if guid in world.player_name_lookup:
            return
        world.player_name_lookup[guid] = name
        pending = world.queued_chat_messages.get(guid)
        while pending:
            message = pending.popleft()
            message.sender.sender = name
            self._ui.present_chat_message(message)
