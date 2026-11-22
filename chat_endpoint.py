"""Read the active WoW client's realmlist without modifying it."""

import ipaddress
from pathlib import Path
import re
import shlex


DEFAULT_HOST = "wow.reinosdeleyenda.org"
DEFAULT_PORT = 3724


def validate_endpoint(host, port):
    host = host.strip().lower().rstrip(".")
    if host.startswith("[") and host.endswith("]"):
        host = host[1:-1]
    if ":" in host:
        try:
            host = str(ipaddress.IPv6Address(host))
        except ValueError:
            raise ValueError("Introduce una dirección de servidor válida.") from None
    elif not re.fullmatch(r"(?=.{1,253}\Z)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
                          r"(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*", host):
        raise ValueError("Introduce una dirección de servidor válida.")
    if not re.fullmatch(r"[0-9]{1,5}", str(port).strip()) or not 1 <= int(port) <= 65535:
        raise ValueError("El puerto debe estar entre 1 y 65535.")
    return host, int(port)


def read_realmlist(path):
    """Return a valid host and port or the project's default."""
    try:
        lines = Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines()
    except (OSError, TypeError):
        lines = ()
    for line in lines:
        if not re.match(r"^\s*set\s+realmlist\s+", line, re.IGNORECASE):
            continue
        try:
            _, _, address, *_ = shlex.split(line, comments=True)
            if address.startswith("["):
                tail = re.fullmatch(r"\[([^\]]+)\](?::([0-9]+))?", address)
                if not tail:
                    continue
                host, port = tail.group(1), tail.group(2) or DEFAULT_PORT
            elif address.count(":") == 1:
                host, port = address.split(":")
            else:
                host, port = address, DEFAULT_PORT
            return validate_endpoint(host, port)
        except ValueError:
            continue
    return DEFAULT_HOST, DEFAULT_PORT

