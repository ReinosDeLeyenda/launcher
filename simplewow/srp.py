"""Client side of the WoW SRP-6 logon (the maths from Authentication/Network/AuthSocket.cs).

All big numbers on the wire are little-endian and fixed width (32 bytes for the
3.3.5a modulus). The C# version used BigInteger.ToByteArray(), which drops leading
zero bytes (1 in 256 values) and whose ModPow can return a negative result for a
negative base; Python's integers and fixed-width encoding avoid both problems.
"""
from __future__ import annotations

import secrets
from dataclasses import dataclass
from typing import Callable

from .crypto import sha1

K_MULTIPLIER = 3


@dataclass
class SrpResult:
    A: bytes             # client public key (sent to the server)
    M1: bytes            # client proof (sent to the server)
    K: bytes             # 40-byte session key
    M2_expected: bytes   # proof the server must send back
    S: bytes             # raw shared secret (for debug output)


def _le(data: bytes) -> int:
    return int.from_bytes(data, "little")


def password_hash(username: str, password: str) -> bytes:
    return sha1(f"{username}:{password}".upper().encode("utf-8"))


def interleave_session_key(s: bytes) -> bytes:
    """Split S into even/odd bytes, hash each half with SHA-1 and interleave -> 40 bytes."""
    if len(s) != 32:
        raise ValueError("S must be 32 bytes")
    even = sha1(bytes(s[i * 2] for i in range(16)))
    odd = sha1(bytes(s[i * 2 + 1] for i in range(16)))
    key = bytearray(40)
    key[0::2] = even
    key[1::2] = odd
    return bytes(key)


def compute_client_proof(
    username: str,
    password: str,
    B: bytes,
    g: bytes,
    N: bytes,
    salt: bytes,
    rand: Callable[[int], bytes] = secrets.token_bytes,
) -> SrpResult:
    width = len(N)
    n, gi, b = _le(N), _le(g), _le(B)
    if b % n == 0:
        raise ValueError("server sent an invalid public key")

    user = username.upper().encode("utf-8")
    x = _le(sha1(salt, password_hash(username, password)))

    while True:
        a = _le(rand(19))
        A = pow(gi, a, n)
        if A % n != 0:
            break
    a_bytes = A.to_bytes(width, "little")

    u = _le(sha1(a_bytes, B))
    if u == 0:
        raise ValueError("invalid scrambling parameter")

    # S = (B - k*g^x) ^ (a + u*x) mod N   -- reduce the base first so it is never negative
    base = (b - K_MULTIPLIER * pow(gi, x, n)) % n
    s_bytes = pow(base, a + u * x, n).to_bytes(width, "little")
    session_key = interleave_session_key(s_bytes)

    g_n_hash = bytes(x1 ^ x2 for x1, x2 in zip(sha1(N), sha1(g)))
    m1 = sha1(g_n_hash, sha1(user), salt, a_bytes, B, session_key)
    m2 = sha1(a_bytes, m1, session_key)
    return SrpResult(A=a_bytes, M1=m1, K=session_key, M2_expected=m2, S=s_bytes)
