from enum import IntEnum
from dataclasses import dataclass
from typing import Tuple


class MessageType(IntEnum):
    CALL = 0
    UPDATE = 1
    IDENTIFY = 2


# Canali del protocollo
PROTO_RELIABLE_CHANNEL = 0
PROTO_UNRELIABLE_CHANNEL = 1
PROTO_NUM_CHANNELS = 2


@dataclass
class Vec2f:
    x: float
    y: float


@dataclass
class Vec3f:
    x: float
    y: float
    z: float


@dataclass
class Vec2i:
    x: int
    y: int


@dataclass
class Vec3i:
    x: int
    y: int
    z: int


TYPE_FORMATS = {
    'uint8': ('B', 1),
    'int8': ('b', 1),
    'uint16': ('H', 2),
    'int16': ('h', 2),
    'uint32': ('I', 4),
    'int32': ('i', 4),
    'uint64': ('Q', 8),
    'int64': ('q', 8),
    'float32': ('f', 4),
    'float64': ('d', 8),
}


def get_type_info(type_name: str) -> Tuple[str, int]:
    return TYPE_FORMATS.get(type_name, ('B', 1))
