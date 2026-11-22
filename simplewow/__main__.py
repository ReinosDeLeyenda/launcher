"""Entry point (port of CLIClient/Program.cs and its Settings defaults)."""
from __future__ import annotations

import argparse
import os
import sys

from .cli_ui import CommandLineUI
from .definitions import LogLevel
from .game import Game


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="simplewow", description="Text-only WoW 3.3.5a chat client")
    parser.add_argument("--hostname", default="localhost", help="realm server host (default: localhost)")
    parser.add_argument("--port", type=int, default=3724, help="realm server port (default: 3724)")
    parser.add_argument("--username", default="admin", help="account name (default: admin)")
    parser.add_argument(
        "--password",
        default=os.environ.get("SIMPLEWOW_PASSWORD", "admin"),
        help="account password (default: $SIMPLEWOW_PASSWORD, else 'admin')",
    )
    parser.add_argument(
        "--log-level", default="Info", choices=[level.name for level in LogLevel],
        type=lambda s: s.capitalize(), help="Debug, Detail, Warning, Info or Error (default: Info)",
    )
    args = parser.parse_args(argv)

    for stream in (sys.stdout, sys.stdin):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")

    game = Game(
        CommandLineUI, args.hostname, args.port, args.username, args.password, LogLevel[args.log_level]
    )
    game.start()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
