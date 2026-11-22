"""Enums shared across the client (Client/World/Definitions, Client/Chat/Definitions, UI/LogLevel)."""
from __future__ import annotations

from enum import IntEnum, IntFlag


class LogLevel(IntEnum):
    # Order kept from the C# source: a message is shown when level >= configured level.
    Debug = 0
    Detail = 1
    Warning = 2
    Info = 3
    Error = 4


class Gender(IntEnum):
    Male = 0
    Female = 1
    NoGender = 2  # "None" in the C# source


class PlayerClass(IntEnum):  # "Class" in the C# source
    Warrior = 1
    Paladin = 2
    Hunter = 3
    Rogue = 4
    Priest = 5
    DeathKnight = 6
    Shaman = 7
    Mage = 8
    Warlock = 9
    Druid = 11


class Race(IntEnum):
    Human = 1
    Orc = 2
    Dwarf = 3
    Nightelf = 4
    Undead = 5
    Tauren = 6
    Gnome = 7
    Troll = 8
    Goblin = 9
    Bloodelf = 10
    Draenei = 11
    FelOrc = 12
    Naga = 13
    Broken = 14
    Skeleton = 15
    Vrykul = 16
    Tuskarr = 17
    ForestTroll = 18
    Taunka = 19
    NorthrendSkeleton = 20
    IceTroll = 21


_HORDE = {Race.Bloodelf, Race.Orc, Race.Tauren, Race.Troll, Race.Undead}
_ALLIANCE = {Race.Draenei, Race.Dwarf, Race.Gnome, Race.Human, Race.Nightelf}


def is_horde(race: int) -> bool:
    return race in _HORDE


def is_alliance(race: int) -> bool:
    return race in _ALLIANCE


class ChatMessageType(IntEnum):
    System = 0
    Say = 1
    Party = 2
    Raid = 3
    Guild = 4
    Officer = 5
    Yell = 6
    Whisper = 7
    WhisperForeign = 8
    WhisperInform = 9
    Emote = 10
    TextEmote = 11
    MonsterSay = 12
    MonsterParty = 13
    MonsterYell = 14
    MonsterWhisper = 15
    MonsterEmote = 16
    Channel = 17
    ChannelJoin = 18
    ChannelLeave = 19
    ChannelList = 20
    ChannelNotice = 21
    ChannelNoticeUser = 22
    Afk = 23
    Dnd = 24
    Ignored = 25
    Skill = 26
    Loot = 27
    Money = 28
    Opening = 29
    Tradeskills = 30
    PetInfo = 31
    CombatMiscInfo = 32
    CombatXPGain = 33
    CombatHonorGain = 34
    CombatFactionChange = 35
    BattlegroundNeutral = 36
    BattlegroundAlliance = 37
    BattlegroundHorde = 38
    RaidLeader = 39
    RaidWarning = 40
    RaidBossEmote = 41
    RaidBossWhisper = 42
    Filtered = 43
    Battleground = 44
    BattlegroundLeader = 45
    Restricted = 46
    BattleNet = 47
    Achievement = 48
    GuildAchievement = 49
    ArenaPoints = 50
    PartyLeader = 51
    TargetIcons = 52
    Addon = 0xFFFFFFFF


class ChatTag(IntFlag):
    NONE = 0x0  # "None" in the C# source
    Afk = 0x1
    Dnd = 0x2
    Gm = 0x4
    Unknown = 0x8


class Language(IntEnum):
    Universal = 0
    Orcish = 1
    Darnassian = 2
    Taurahe = 3
    Dwarvish = 6
    Common = 7
    Demonic = 8
    Titan = 9
    Thalassian = 10
    Draconic = 11
    Kalimag = 12
    Gnomish = 13
    Troll = 14
    Gutterspeak = 33
    Draenei = 35
    Zombie = 36
    GnomishBinary = 37
    GoblinBinary = 38
    Addon = 0xFFFFFFFF


def enum_name(enum_cls, value) -> str:
    """Name of an enum member, or the raw number if the server sent an unknown value."""
    try:
        return enum_cls(value).name
    except ValueError:
        return str(int(value))
