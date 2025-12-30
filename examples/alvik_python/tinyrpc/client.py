import random
import time
import threading
from typing import Optional, Callable
from .types import PROTO_RELIABLE_CHANNEL, PROTO_UNRELIABLE_CHANNEL, PROTO_NUM_CHANNELS

try:
    import enet
    ENET_AVAILABLE = True
except ImportError:
    ENET_AVAILABLE = False
    print("Warning: pyenet is not installed")


class ClientAbstraction:

    def __init__(self):
        self._host: Optional['enet.Host'] = None
        self._peer: Optional['enet.Peer'] = None
        self._address: Optional['enet.Address'] = None
        self._peer_id: int = 0
        self._is_connected: bool = False
        self._lock = threading.RLock()

    def begin(self, hostname: str, port: int) -> bool:
       
        if not ENET_AVAILABLE:
            print("Error: pyenet is not installed")
            return False

        try:
            self._address = enet.Address(hostname.encode(), port)
            self._host = enet.Host(None, 1, PROTO_NUM_CHANNELS, 0, 0)

            if self._host is None:
                return False

            self._peer_id = self.generate_unique_id()
            self._try_connect()
            return True

        except Exception as e:
            print(f"Initialisation error: {e}")
            return False

    def _try_connect(self):
        if self._host and self._address:
            self._peer = self._host.connect(self._address, PROTO_NUM_CHANNELS, self._peer_id)

    def is_connected(self) -> bool:
        return self._is_connected

    def on_connect(self):
        pass

    def on_disconnect(self):
        pass

    def on_message(self, data: bytes, data_size: int):
        pass

    def generate_unique_id(self) -> int:
        random.seed(time.time())
        return random.randint(0, 2**31 - 1)

    def send_message(self, data: bytes, reliable: bool = False):
        if not ENET_AVAILABLE or not self._peer:
            return

        with self._lock:
            flags = 0
            if reliable:
                flags = enet.PACKET_FLAG_RELIABLE
            
            channel = PROTO_RELIABLE_CHANNEL if reliable else PROTO_UNRELIABLE_CHANNEL
            
            packet = enet.Packet(data, flags)
            self._peer.send(channel, packet)
            
            if self._host:
                self._host.flush()

    def service(self):
        if not ENET_AVAILABLE or not self._host:
            return

        with self._lock:
            self._enet_service()

    def _enet_service(self):
        while True:
            event = self._host.service(0)
            
            if event is None:
                break
                
            if event.type == enet.EVENT_TYPE_NONE:
                break
                
            elif event.type == enet.EVENT_TYPE_CONNECT:
                self._is_connected = True
                self.on_connect()
                
            elif event.type == enet.EVENT_TYPE_DISCONNECT:
                self._is_connected = False
                self.on_disconnect()
                self._try_connect()
                
            elif event.type == enet.EVENT_TYPE_RECEIVE:
                data = event.packet.data
                length = len(data)
                self.on_message(data, length)

    def disconnect(self):
        if self._peer:
            self._peer.disconnect()
        if self._host:
            self._host = None
        self._is_connected = False
