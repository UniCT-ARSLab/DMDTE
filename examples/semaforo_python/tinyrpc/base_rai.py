
import struct
from dataclasses import dataclass, field
from typing import (
    Any, Callable, Dict, Generic, List, Optional, 
    TypeVar, Union, get_type_hints
)

from .client import ClientAbstraction
from .types import MessageType, get_type_info

T = TypeVar('T')
Context = TypeVar('Context')


@dataclass
class PropertyDescriptor(Generic[T]):
    name: str
    type_name: str = 'uint8'  # uint8, int8, uint16, int16, uint32, int32, float32, float64
    getter: Optional[Callable[['BaseRAI'], T]] = None
    setter: Optional[Callable[['BaseRAI', T], None]] = None


@dataclass
class MethodDescriptor:
    name: str
    handler: Callable[['BaseRAI', bytes, int], None]


@dataclass
class Property:
    name: str
    index: int
    size: int
    type_name: str
    struct_format: str
    getter: Optional[Callable] = None
    setter: Optional[Callable] = None


@dataclass
class Method:
    name: str
    index: int
    handler: Callable


class BaseRAI(ClientAbstraction):

    def __init__(self):
        super().__init__()
        self._agent_identification: str = "BaseRAI"
        self._properties: List[Property] = []
        self._methods: List[Method] = []
        self._property_storage: bytearray = bytearray()
        self._update_storage: bytearray = bytearray()
        self._dtp_connected = False

    def set_agent_identification(self, agent_identification: str):
        self._agent_identification = agent_identification

    def export_property(self, descriptor: PropertyDescriptor):
        struct_format, size = get_type_info(descriptor.type_name)
        
        prop = Property(
            name=descriptor.name,
            index=len(self._properties),
            size=size,
            type_name=descriptor.type_name,
            struct_format=struct_format,
            getter=descriptor.getter,
            setter=descriptor.setter
        )
        
        if prop.getter is not None:
            offset = len(self._property_storage)
            self._property_storage.extend(bytes(prop.size))
        
        self._properties.append(prop)

    def export_method(self, descriptor: MethodDescriptor):
        method = Method(
            name=descriptor.name,
            index=len(self._methods),
            handler=descriptor.handler
        )
        self._methods.append(method)

    def call(self, method_index: int, args: bytes):
        arg_size = len(args)
        msg_size = 4 + arg_size
        
        message = bytearray(msg_size)
        message[0] = MessageType.CALL
        message[1] = method_index
        struct.pack_into('<H', message, 2, arg_size)
        message[4:4+arg_size] = args
        
        self.send_message(bytes(message), reliable=True)

    def update(self, full_and_reliable: bool = False):

        self._update_storage = bytearray()
        self._update_storage.extend(bytes(2))
        
        written_properties = 0
        
        for prop in self._properties:
            if prop.getter is not None:
                self._write_property(prop)
                written_properties += 1
        
        if written_properties > 0 and self.is_connected():
            self._update_storage[0] = MessageType.UPDATE
            self._update_storage[1] = written_properties
            self.send_message(bytes(self._update_storage), reliable=full_and_reliable)

    def _write_property(self, prop: Property):

        self._update_storage.append(prop.index)
        self._update_storage.append(prop.size)
        
        if prop.getter:
            value = prop.getter(self)
            packed = struct.pack('<' + prop.struct_format, value)
            self._update_storage.extend(packed)

    def service(self):
        super().service()
        self.update(full_and_reliable=True)

    def on_connect(self):
        super().on_connect()
        self._send_agent_identification()
        self._dtp_connected = True
    
    def on_disconnect(self):
        super().on_disconnect()
        self._dtp_connected = False

    def is_dtp_connected(self) -> bool:
        return self._dtp_connected


    def _send_agent_identification(self):
        msg_size = 1 + len(self._agent_identification)
        message = bytearray(msg_size)
        message[0] = MessageType.IDENTIFY
        message[1:] = self._agent_identification.encode('utf-8')
        self.send_message(bytes(message), reliable=True)

    def on_message(self, data: bytes, data_size: int):
        if data_size < 1:
            return
            
        msg_type = MessageType(data[0])
        
        if msg_type == MessageType.CALL:
            self._on_call(data, data_size)
        elif msg_type == MessageType.UPDATE:
            self._on_update(data, data_size)

    def _on_call(self, data: bytes, data_size: int):
        if data_size < 4:
            return
            
        method_index = data[1]
        arg_size = struct.unpack_from('<H', data, 2)[0]
        fwd_args = data[4:4+arg_size]
        
        if method_index < len(self._methods):
            self._methods[method_index].handler(self, fwd_args, arg_size)

    def _on_update(self, data: bytes, data_size: int):
        if data_size < 2:
            return
            
        num_properties = data[1]
        offset = 2
        
        for _ in range(num_properties):
            if offset + 2 > data_size:
                break
                
            index = data[offset]
            size = data[offset + 1]
            offset += 2
            
            if offset + size > data_size:
                break
                
            if index < len(self._properties):
                prop = self._properties[index]
                if prop.setter:
                    value_data = data[offset:offset+size]
                    value = struct.unpack('<' + prop.struct_format, value_data)[0]
                    prop.setter(self, value)
            
            offset += size


class SimpleRAI(BaseRAI):
    
    def __init__(self):
        super().__init__()
        self._exported_attrs: Dict[str, str] = {}  
    
    def export_attribute(self, name: str, type_name: str = 'uint8', initial_value: Any = 0):
        
        setattr(self, name, initial_value)
        self._exported_attrs[name] = type_name
        
        descriptor = PropertyDescriptor(
            name=name,
            type_name=type_name,
            getter=lambda self, n=name: getattr(self, n),
            setter=lambda self, v, n=name: setattr(self, n, v)
        )
        
        self.export_property(descriptor)
