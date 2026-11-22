"""Crypto primitives (port of Client/Crypto/* and World/Network/AuthenticationCrypto.cs)."""
from __future__ import annotations

import hashlib
import hmac
import threading
from enum import Enum


def sha1(*parts: bytes) -> bytes:
    """SHA-1 over the concatenation of all parts (HashHelper.Hash)."""
    h = hashlib.sha1()
    for part in parts:
        h.update(part)
    return h.digest()


class ARC4:
    """Plain RC4 stream cipher (the same stream is used for both directions of a transform)."""

    def __init__(self, key: bytes) -> None:
        state = list(range(256))
        j = 0
        for i in range(256):
            j = (j + state[i] + key[i % len(key)]) & 0xFF
            state[i], state[j] = state[j], state[i]
        self._state = state
        self._x = 0
        self._y = 0

    def process(self, data: bytes) -> bytes:
        state = self._state
        x, y = self._x, self._y
        out = bytearray(len(data))
        for n, byte in enumerate(data):
            x = (x + 1) & 0xFF
            y = (state[x] + y) & 0xFF
            state[x], state[y] = state[y], state[x]
            out[n] = byte ^ state[(state[x] + state[y]) & 0xFF]
        self._x, self._y = x, y
        return bytes(out)


class AuthStatus(Enum):
    Uninitialized = 0
    Pending = 1
    Ready = 2


# Fixed HMAC keys of the 3.3.5a world protocol (client -> server / server -> client).
ENCRYPTION_KEY = bytes([
    0xC2, 0xB3, 0x72, 0x3C, 0xC6, 0xAE, 0xD9, 0xB5,
    0x34, 0x3C, 0x53, 0xEE, 0x2F, 0x43, 0x67, 0xCE,
])
DECRYPTION_KEY = bytes([
    0xCC, 0x98, 0xAE, 0x04, 0xE8, 0x97, 0xEA, 0xCA,
    0x12, 0xDD, 0xC0, 0x93, 0x42, 0x91, 0x53, 0x57,
])


class AuthenticationCrypto:
    """Header encryption for one world connection.

    The C# version kept this in static state; here it is an instance owned by the
    WorldSocket. Both directions are no-ops until `initialize` has been called.
    """

    def __init__(self) -> None:
        self.status = AuthStatus.Uninitialized
        self._encrypt_stream: ARC4 | None = None
        self._decrypt_stream: ARC4 | None = None
        self._lock = threading.Lock()

    def initialize(self, session_key: bytes) -> None:
        enc = ARC4(hmac.new(ENCRYPTION_KEY, session_key, hashlib.sha1).digest())
        enc.process(bytes(1024))  # RC4-drop[1024]
        dec = ARC4(hmac.new(DECRYPTION_KEY, session_key, hashlib.sha1).digest())
        dec.process(bytes(1024))
        with self._lock:
            self._encrypt_stream, self._decrypt_stream = enc, dec
            self.status = AuthStatus.Ready

    def encrypt(self, data: bytes) -> bytes:
        if self.status != AuthStatus.Ready:
            return data
        return self._encrypt_stream.process(data)

    def decrypt(self, data: bytes) -> bytes:
        if self.status != AuthStatus.Ready:
            return data
        return self._decrypt_stream.process(data)
