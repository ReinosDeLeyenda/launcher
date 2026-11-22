"""Realm (auth) server connection: logon, SRP proof and realm list.

Port of the Client/Authentication/* files. The C# version used asynchronous callbacks
that re-armed a one-byte read; here the whole handshake is a straight-line blocking
sequence, which is equivalent for this strictly request/response protocol.
"""
from __future__ import annotations

import hmac
import socket
import struct
from enum import IntEnum
from typing import TYPE_CHECKING, Iterator, Optional

from .definitions import LogLevel
from .srp import compute_client_proof
from .util import ByteReader, recv_exact, to_cstring, to_hex_string

if TYPE_CHECKING:  # pragma: no cover
    from .game import Game

CLIENT_BUILD = 12340
CLIENT_VERSION = (3, 3, 5)


class AuthCommand(IntEnum):
    LOGON_CHALLENGE = 0x00
    LOGON_PROOF = 0x01
    REALM_LIST = 0x10
    TRANSFER_INITIATE = 0x30
    TRANSFER_DATA = 0x31
    TRANSFER_ACCEPT = 0x32
    TRANSFER_RESUME = 0x33
    TRANSFER_CANCEL = 0x34


class AuthResult(IntEnum):
    SUCCESS = 0
    FAILURE = 0x01
    UNKNOWN1 = 0x02
    ACCOUNT_BANNED = 0x03
    NO_MATCH = 0x04
    UNKNOWN2 = 0x05
    ACCOUNT_IN_USE = 0x06
    PREPAID_TIME_LIMIT = 0x07
    SERVER_FULL = 0x08
    WRONG_BUILD_NUMBER = 0x09
    UPDATE_CLIENT = 0x0A
    UNKNOWN3 = 0x0B
    ACCOUNT_FREEZED = 0x0C
    UNKNOWN4 = 0x0D
    UNKNOWN5 = 0x0E
    PARENTAL_CONTROL = 0x0F


class WorldServerInfo:
    """One entry of the realm list."""

    def __init__(self, reader: ByteReader) -> None:
        self.type = reader.read_u8()
        self.locked = reader.read_u8()
        self.flags = reader.read_u8()
        self.name = reader.read_cstring()
        address = reader.read_cstring()
        host, _, port = address.partition(":")
        self.address = host
        self.port = int(port) if port else 8085
        self.population = reader.read_float()
        self.load = reader.read_u8()
        self.timezone = reader.read_u8()
        self.realm_id = reader.read_u8()  # "unk1" in the C# source
        if self.flags & 4:
            self.version_major = reader.read_u8()
            self.version_minor = reader.read_u8()
            self.version_bugfix = reader.read_u8()
            self.build = reader.read_u16()


class WorldServerList:
    def __init__(self, reader: ByteReader) -> None:
        reader.read_u32()
        count = reader.read_u16()
        self._servers = [WorldServerInfo(reader) for _ in range(count)]

    @property
    def count(self) -> int:
        return len(self._servers)

    def __len__(self) -> int:
        return len(self._servers)

    def __getitem__(self, index: int) -> WorldServerInfo:
        return self._servers[index]

    def __iter__(self) -> Iterator[WorldServerInfo]:
        return iter(self._servers)


class AuthSocket:
    def __init__(self, game: "Game", hostname: str, port: int, username: str, password: str) -> None:
        self.game = game
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.key: bytes = b""  # 40-byte session key after a successful logon
        self._sock: Optional[socket.socket] = None
        self._closing = False

    # -- helpers ---------------------------------------------------------------------

    @property
    def _ui(self):
        return self.game.ui

    def _read_command(self) -> int:
        value = recv_exact(self._sock, 1)[0]
        try:
            return AuthCommand(value)
        except ValueError:
            return value

    def close(self) -> None:
        self._closing = True
        sock = self._sock
        if sock is not None:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            sock.close()

    # -- logon -------------------------------------------------------------------------

    def connect(self) -> bool:
        if self._closing:
            return False
        self._ui.log("Connecting to realmlist... ")
        try:
            self._sock = socket.create_connection((self.hostname, self.port), timeout=15)
            if self._closing:
                self.close()
                return False
        except OSError as ex:
            self._ui.log_line(f"failed. ({ex})", LogLevel.Error)
            return False
        self._ui.log_line("done!")
        return True

    def authenticate(self) -> Optional[WorldServerList]:
        """Run the whole realm-server handshake. Returns the realm list, or None on failure."""
        if not self.connect():
            return None
        try:
            return self._authenticate()
        except (ConnectionError, EOFError):
            self._ui.log_line("Server has disconnected.", LogLevel.Info)
            return None
        except OSError as ex:
            self._ui.log_line(f"Network error: {ex}", LogLevel.Error)
            return None
        except ValueError as ex:
            self._ui.log_line(f"Authentication failed: {ex}", LogLevel.Error)
            return None

    def _send_logon_challenge(self) -> None:
        self._ui.log_line("Sending logon challenge", LogLevel.Debug)
        name = self.username.upper().encode("utf-8")
        try:
            ip = socket.inet_aton(self._sock.getsockname()[0])
        except OSError:  # e.g. IPv6 local address
            ip = bytes(4)
        packet = (
            bytes([AuthCommand.LOGON_CHALLENGE, 6])      # command, protocol version
            + struct.pack("<H", len(name) + 30)          # size of the rest
            + to_cstring("WoW")
            + bytes(CLIENT_VERSION)
            + struct.pack("<H", CLIENT_BUILD)
            + to_cstring("68x")      # "x86" reversed
            + to_cstring("niW")      # "Win" reversed
            + b"SUne"                # "enUS" reversed
            + struct.pack("<I", 0x3C)  # timezone bias
            + ip
            + bytes([len(name)])
            + name
        )
        self._sock.sendall(packet)

    def _authenticate(self) -> Optional[WorldServerList]:
        ui = self._ui
        self._send_logon_challenge()

        # ---- server challenge ----
        command = self._read_command()
        if command != AuthCommand.LOGON_CHALLENGE:
            ui.log_line(f"Unknown or unhandled command '{command}'", LogLevel.Debug)
            return None
        reader_head = recv_exact(self._sock, 2)  # unk2, error
        error = reader_head[1]
        if error != AuthResult.SUCCESS:
            messages = {
                AuthResult.NO_MATCH: "Unknown account name",
                AuthResult.ACCOUNT_IN_USE: "Account already logged in",
                AuthResult.WRONG_BUILD_NUMBER: "Wrong build number",
                AuthResult.ACCOUNT_BANNED: "Account is banned",
            }
            ui.log_line(messages.get(error, f"Logon challenge failed (error {error})"), LogLevel.Error)
            return None

        body = ByteReader(recv_exact(self._sock, 32 + 1 + 1 + 1 + 32 + 32 + 16 + 1))
        B = body.read_bytes(32)
        body.read_u8()                 # g length
        g = body.read_bytes(1)
        body.read_u8()                 # N length
        N = body.read_bytes(32)
        salt = body.read_bytes(32)
        body.read_bytes(16)            # version challenge ("unk3")
        security_flags = body.read_u8()
        if security_flags:
            ui.log_line(
                "This account requires extra security (PIN/matrix/authenticator), which is not supported.",
                LogLevel.Error,
            )
            return None
        ui.log_line("Received logon challenge", LogLevel.Debug)

        srp = compute_client_proof(self.username, self.password, B, g, N, salt)
        self.key = srp.K

        ui.log_line("---====== Received from server: ======---", LogLevel.Debug)
        ui.log_line(f"B={to_hex_string(B)}", LogLevel.Debug)
        ui.log_line(f"N={to_hex_string(N)}", LogLevel.Debug)
        ui.log_line(f"salt={to_hex_string(salt)}", LogLevel.Debug)
        ui.log_line("---====== Send data to server: ======---", LogLevel.Debug)
        ui.log_line(f"A={to_hex_string(srp.A)}", LogLevel.Debug)
        ui.log_line(f"S={to_hex_string(srp.S)}", LogLevel.Debug)
        ui.log_line(f"K={to_hex_string(srp.K)}", LogLevel.Debug)
        ui.log_line(f"M={to_hex_string(srp.M1)}", LogLevel.Debug)

        ui.log_line("Sending logon proof", LogLevel.Debug)
        self._sock.sendall(
            bytes([AuthCommand.LOGON_PROOF]) + srp.A + srp.M1 + bytes(20) + b"\x00\x00"
        )

        # ---- server proof ----
        command = self._read_command()
        if command != AuthCommand.LOGON_PROOF:
            ui.log_line(f"Unknown or unhandled command '{command}'", LogLevel.Debug)
            return None
        error = recv_exact(self._sock, 1)[0]
        if error != AuthResult.SUCCESS:
            recv_exact(self._sock, 2)
            if error == AuthResult.UPDATE_CLIENT:
                ui.log_line("Client update requested")
            elif error in (AuthResult.NO_MATCH, AuthResult.UNKNOWN2):
                ui.log_line("Wrong password or invalid account or authentication error", LogLevel.Error)
            elif error == AuthResult.WRONG_BUILD_NUMBER:
                ui.log_line("Wrong build number", LogLevel.Error)
            else:
                ui.log_line(f"Unknown error {error}", LogLevel.Error)
            return None

        proof = ByteReader(recv_exact(self._sock, 20 + 4 + 4 + 2))
        m2 = proof.read_bytes(20)
        ui.log_line("Received logon proof", LogLevel.Debug)
        if not hmac.compare_digest(m2, srp.M2_expected):
            ui.log_line("Server auth failed!", LogLevel.Error)
            return None
        ui.log_line("Authentication succeeded!")

        # ---- realm list ----
        ui.log_line("Requesting realm list", LogLevel.Detail)
        self._sock.sendall(bytes([AuthCommand.REALM_LIST]) + struct.pack("<I", 0))
        command = self._read_command()
        if command != AuthCommand.REALM_LIST:
            ui.log_line(f"Unknown or unhandled command '{command}'", LogLevel.Debug)
            return None
        (size,) = struct.unpack("<H", recv_exact(self._sock, 2))
        realms = WorldServerList(ByteReader(recv_exact(self._sock, size)))
        ui.log_line("Received realm list", LogLevel.Debug)
        return realms
