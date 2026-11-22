"""World packet containers (port of World/Network/InPacket.cs, OutPacket.cs, ClientHeader.cs)."""
from __future__ import annotations

import struct

from .crypto import AuthenticationCrypto
from .opcodes import WorldCommand
from .util import ByteReader, to_cstring


class InPacket(ByteReader):
    """A received world packet: opcode plus payload reader."""

    def __init__(self, command: int, data: bytes = b"") -> None:
        super().__init__(data)
        self.command = command


class OutPacket:
    """A world packet being built for sending."""

    def __init__(self, command: WorldCommand) -> None:
        self.command = command
        self._buf = bytearray()

    def write_u8(self, value: int) -> None:
        self._buf += struct.pack("<B", value)

    def write_u16(self, value: int) -> None:
        self._buf += struct.pack("<H", value)

    def write_u32(self, value: int) -> None:
        self._buf += struct.pack("<I", value)

    def write_u64(self, value: int) -> None:
        self._buf += struct.pack("<Q", value)

    def write_bytes(self, value: bytes) -> None:
        self._buf += value

    def write_cstring(self, value: str) -> None:
        self._buf += to_cstring(value)

    def build(self, crypto: AuthenticationCrypto) -> bytes:
        """Serialise with the client header: 2-byte big-endian size (payload + 4),
        4-byte little-endian opcode. Both header parts are encrypted together, in
        that order, once the session crypto is ready. Call this while holding the
        socket's send lock so the RC4 stream order matches the wire order."""
        size = len(self._buf) + 4
        if size > 0xFFFF:
            raise ValueError("packet too large")
        header = struct.pack(">H", size) + struct.pack("<I", int(self.command))
        return crypto.encrypt(header) + bytes(self._buf)
