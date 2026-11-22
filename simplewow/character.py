"""Character list entry (port of Client/World/CharacterEnumeration.cs)."""
from __future__ import annotations

from .packets import InPacket


class Item:
    def __init__(self, packet: InPacket) -> None:
        self.display_id = packet.read_u32()
        self.inventory_type = packet.read_u8()
        packet.read_u32()  # enchantment aura


class Character:
    def __init__(self, packet: InPacket) -> None:
        self.guid = packet.read_u64()
        self.name = packet.read_cstring()
        self.race = packet.read_u8()
        self.player_class = packet.read_u8()
        self.gender = packet.read_u8()
        self.appearance = packet.read_bytes(5)  # skin, face, hair style, hair colour, facial hair
        self.level = packet.read_u8()
        self.zone_id = packet.read_u32()
        self.map_id = packet.read_u32()
        self.x = packet.read_float()
        self.y = packet.read_float()
        self.z = packet.read_float()
        self.guild_id = packet.read_u32()
        self.flags = packet.read_u32()
        packet.read_u32()   # customize flags (rename, etc.)
        packet.read_u8()    # first login
        self.pet_info_id = packet.read_u32()
        self.pet_level = packet.read_u32()
        self.pet_family_id = packet.read_u32()

        # 19 equipment slots, then 4 bag slots (same record layout)
        self.items = [Item(packet) for _ in range(19)]
        for _ in range(4):
            Item(packet)
