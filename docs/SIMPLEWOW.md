# SimpleWoW (Python)

A Python port of [Aokromes/SimpleWoW](https://github.com/Aokromes/SimpleWoW): a tiny text client for
chatting on a World of Warcraft **3.3.5a (build 12340)** server without starting the game. It logs in
to the realm server, lets you pick a realm and character, enters the world and gives you chat
key bindings. Standard library only, Python 3.9+.

```
python -m simplewow --hostname localhost --port 3724 --username admin --password admin
```

Defaults match the original `app.config` (localhost, 3724, admin/admin, log level Info). The password
can also come from `SIMPLEWOW_PASSWORD`. `--log-level` is one of Debug, Detail, Warning, Info, Error.

Keys once a character is in the world: **S** say, **Y** yell, **G** guild, **O** officer,
**W** whisper (`Q` cancels), **R** reply (Tab cycles recent whisperers, Enter selects, Esc cancels).
Output is also written to a timestamped `.log` file in the working directory, as in the original.

## Where things went

| C# | Python |
|---|---|
| `CLIClient/Program.cs`, `Settings` | `simplewow/__main__.py` (argparse) |
| `Client/Game.cs`, `World.cs` | `simplewow/game.py` |
| `Authentication/*` (packets, `AuthSocket`) | `simplewow/auth.py`, SRP maths in `simplewow/srp.py` |
| `Crypto/*`, `AuthenticationCrypto.cs` | `simplewow/crypto.py` |
| `World/Network/*` (`WorldSocket`, headers, handlers) | `simplewow/world_socket.py`, `simplewow/packets.py` |
| `WorldCommand.cs` (1300 opcodes) | `simplewow/opcodes.py` (generated, names unchanged) |
| `CharacterEnumeration.cs` | `simplewow/character.py` |
| `Chat/*`, `World/Definitions/*`, `LogLevel` | `simplewow/chat.py`, `simplewow/definitions.py` |
| `IGameUI`, `CommandLineUI`, key bind handlers | `simplewow/ui.py`, `simplewow/cli_ui.py` |

## Intentional differences from the C# code

- **Blocking sockets and two threads** instead of `BeginReceive` callbacks: one reader thread, one
  worker running packet handlers *in order* (the C# thread-pool dispatch did not keep order).
- **SRP uses fixed 32-byte little-endian values and non-negative modular arithmetic.** The C# code
  has a `TODO` saying the session key comes out wrong; likely causes are `BigInteger.ModPow` with a
  negative base, byte arrays losing a leading zero (1 in 256), and the account name not being
  upper-cased in the M1 proof. All three are handled.
- The session key is kept as 40 raw bytes (the C# `BigInteger` round-trip could drop a zero byte).
- `CMSG_AUTH_SESSION` sends the realm id from the realm list instead of 0, as the real client does.
- RC4 header encryption happens under the send lock so the stream order matches the wire order.
- A failed logon stops with an error; the C# code re-sent the challenge forever.
- Chat sender lookup uses the sender GUID from the packet header; text is UTF-8 both ways.
- Character list header now matches its columns; character/realm prompts validate their range and
  re-prompt when "create character" is picked (not implemented, as in the original).

Not implemented (same as the original): character creation, channels, keep-alive pings, accounts
with PIN/authenticator, anything other than build 12340.

## Tests

```
python -m unittest discover -s tests -v
```

`tests/mock_server.py` is a small realm + world server written independently of the client (its own
SRP server maths and header handling). The tests check RC4 vectors, 300 SRP handshakes, a full
session (logon, realm list, world auth, encrypted headers incl. the 5-byte large-packet header,
character list, name-query queueing, chat both ways) and concurrent sends.
**These tests have not been run against a real MaNGOS/TrinityCore server.**
