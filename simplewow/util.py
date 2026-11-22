"""Small helpers (port of Client/Extensions.cs)."""
from __future__ import annotations

import socket
import struct


def to_hex_string(data: bytes) -> str:
    """Hex string with the most significant byte first (input is little-endian)."""
    return bytes(reversed(data)).hex().upper()


def to_cstring(text: str) -> bytes:
    """NUL-terminated UTF-8 string."""
    return text.encode("utf-8") + b"\x00"


def recv_exact(sock: socket.socket, count: int) -> bytes:
    """Read exactly `count` bytes or raise ConnectionError if the peer closes."""
    chunks = []
    remaining = count
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError("connection closed by peer")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


class ByteReader:
    """Little-endian reader over a bytes buffer (replacement for BinaryReader)."""

    def __init__(self, data: bytes = b"") -> None:
        self._data = bytes(data)
        self._pos = 0

    @property
    def remaining(self) -> int:
        return len(self._data) - self._pos

    def _unpack(self, fmt: str):
        size = struct.calcsize(fmt)
        if self._pos + size > len(self._data):
            raise EOFError("unexpected end of data")
        (value,) = struct.unpack_from(fmt, self._data, self._pos)
        self._pos += size
        return value

    def read_u8(self) -> int:
        return self._unpack("<B")

    def read_u16(self) -> int:
        return self._unpack("<H")

    def read_u32(self) -> int:
        return self._unpack("<I")

    def read_i32(self) -> int:
        return self._unpack("<i")

    def read_u64(self) -> int:
        return self._unpack("<Q")

    def read_float(self) -> float:
        return self._unpack("<f")

    def read_bool(self) -> bool:
        return self.read_u8() != 0

    def read_bytes(self, count: int) -> bytes:
        if self._pos + count > len(self._data):
            raise EOFError("unexpected end of data")
        value = self._data[self._pos:self._pos + count]
        self._pos += count
        return value

    def read_cstring(self) -> str:
        end = self._data.find(b"\x00", self._pos)
        if end < 0:
            raise EOFError("unterminated string")
        value = self._data[self._pos:end]
        self._pos = end + 1
        return value.decode("utf-8", errors="replace")

    def read_packed_guid(self) -> int:
        mask = self.read_u8()
        guid = 0
        for i in range(8):
            if mask & (1 << i):
                guid |= self.read_u8() << (i * 8)
        return guid
