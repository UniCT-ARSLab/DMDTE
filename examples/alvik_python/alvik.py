import time
import math
import struct
import threading
from dataclasses import dataclass
from typing import Optional

from tinyrpc import BaseRAI, PropertyDescriptor, MethodDescriptor


@dataclass
class Pose:
    x: float = 0.0
    y: float = 0.0
    theta: float = 0.0
    
    def pack(self) -> bytes:
        return struct.pack('<fff', self.x, self.y, self.theta)
    
    @classmethod
    def unpack(cls, data: bytes) -> 'Pose':
        x, y, theta = struct.unpack('<fff', data[:12])
        return cls(x, y, theta)
    
    @classmethod
    def size(cls) -> int:
        return 12  


@dataclass
class DriveSpeed:
    linear: float = 0.0
    angular: float = 0.0
    
    def pack(self) -> bytes:
        return struct.pack('<ff', self.linear, self.angular)
    
    @classmethod
    def unpack(cls, data: bytes) -> 'DriveSpeed':
        linear, angular = struct.unpack('<ff', data[:8])
        return cls(linear, angular)
    
    @classmethod
    def size(cls) -> int:
        return 8  # 2 * float32



class AlvikSimulator:
    
    def __init__(self):
        self._pose = Pose(0.0, 0.0, 0.0)
        self._velocity = DriveSpeed(0.0, 0.0)
        self._battery_charge: float = 85.0
        self._is_charging: bool = False
        
        self._last_update: float = time.time()
        self._running: bool = False
        self._lock = threading.Lock()
    
    def begin(self):
        self._running = True
        print("[Alvik] Robot ready")
    
    def get_battery_charge(self) -> float:
        return self._battery_charge
    
    def is_battery_charging(self) -> bool:
        return self._is_charging
    
    def get_pose(self) -> Pose:
        with self._lock:
            return Pose(self._pose.x, self._pose.y, self._pose.theta)
    
    def reset_pose(self, x: float, y: float, theta: float):
        with self._lock:
            self._pose.x = x
            self._pose.y = y
            self._pose.theta = theta
        print(f"[Alvik] Pose resetted: x={x:.2f}cm, y={y:.2f}cm, θ={math.degrees(theta):.1f}°")
    
    def get_drive_speed(self) -> DriveSpeed:
        with self._lock:
            return DriveSpeed(self._velocity.linear, self._velocity.angular)
    
    def drive(self, linear: float, angular: float):
        with self._lock:
            self._velocity.linear = linear
            self._velocity.angular = angular
        
        if abs(linear) > 0.01 or abs(angular) > 0.01:
            print(f"[Alvik] Drive: linear={linear:.2f}cm/s, angular={math.degrees(angular):.1f}°/s")
    
    def update(self):
        current_time = time.time()
        dt = current_time - self._last_update
        self._last_update = current_time
        
        with self._lock:
            if abs(self._velocity.linear) > 0.001 or abs(self._velocity.angular) > 0.001:
                self._pose.theta += self._velocity.angular * dt
                
                while self._pose.theta > math.pi:
                    self._pose.theta -= 2 * math.pi
                while self._pose.theta < -math.pi:
                    self._pose.theta += 2 * math.pi
                
                self._pose.x += self._velocity.linear * math.cos(self._pose.theta) * dt
                self._pose.y += self._velocity.linear * math.sin(self._pose.theta) * dt
            
            if not self._is_charging and self._battery_charge > 0:
                self._battery_charge -= 0.001 * dt


class AlvikRAI(BaseRAI):
    
    POSE_FORMAT = 'fff'  
    POSE_SIZE = 12
    DRIVESPEED_FORMAT = 'ff'  
    DRIVESPEED_SIZE = 8
    
    def __init__(self, player_number: int = 1):
        super().__init__()
        
        self._alvik = AlvikSimulator()
        self.reset_pose_count: int = 0
        self._player_number = player_number
        self.set_agent_identification("alvik")
        
        self.export_property(PropertyDescriptor(
            name="battery",
            type_name="uint8",
            getter=lambda self: int(self._alvik.get_battery_charge())
        ))
        
        self.export_property(PropertyDescriptor(
            name="is_battery_charging",
            type_name="uint8",
            getter=lambda self: 1 if self._alvik.is_battery_charging() else 0
        ))
        
        self._register_pose_property()
        
        self._register_drive_speed_property()
        
        self.export_method(MethodDescriptor(
            name="drive",
            handler=self._handle_drive
        ))
        
        self.export_method(MethodDescriptor(
            name="reset_pose",
            handler=self._handle_reset_pose
        ))
    
    def _register_pose_property(self):
        from tinyrpc.base_rai import Property
        
        prop = Property(
            name="pose",
            index=len(self._properties),
            size=self.POSE_SIZE,
            type_name="pose",
            struct_format=self.POSE_FORMAT,
            getter=self._get_pose_bytes,
            setter=self._set_pose_bytes
        )
        self._properties.append(prop)
    
    def _register_drive_speed_property(self):
        from tinyrpc.base_rai import Property
        
        prop = Property(
            name="drive_speed",
            index=len(self._properties),
            size=self.DRIVESPEED_SIZE,
            type_name="drive_speed",
            struct_format=self.DRIVESPEED_FORMAT,
            getter=self._get_drive_speed_bytes,
            setter=self._set_drive_speed_bytes
        )
        self._properties.append(prop)
    
    def _get_pose_bytes(self, _) -> bytes:
        pose = self._alvik.get_pose()
        return pose.x, pose.y, pose.theta  
    
    def _set_pose_bytes(self, _, value):
        if isinstance(value, tuple) and len(value) == 3:
            self._alvik.reset_pose(value[0], value[1], value[2])
    
    def _get_drive_speed_bytes(self, _) -> tuple:
        speed = self._alvik.get_drive_speed()
        return speed.linear, speed.angular
    
    def _set_drive_speed_bytes(self, _, value):
        if isinstance(value, tuple) and len(value) == 2:
            self._alvik.drive(value[0], value[1])
    
    def _handle_drive(self, ctx, data: bytes, size: int):
        if size >= self.DRIVESPEED_SIZE:
            vel = DriveSpeed.unpack(data)
            self._alvik.drive(vel.linear, vel.angular)
    
    def _handle_reset_pose(self, ctx, data: bytes, size: int):
        expected_size = self.POSE_SIZE + 4
        
        pose = Pose(0.0, 0.0, 0.0)
        force = 1
        
        if size >= expected_size:
            pose = Pose.unpack(data[:12])
            force = struct.unpack('<i', data[12:16])[0]
        
        if force != 0 or (force == 0 and self.reset_pose_count == 0):
            self._alvik.reset_pose(pose.x, pose.y, pose.theta)
        
        self.reset_pose_count += 1
    
    def alvik(self) -> AlvikSimulator:
        return self._alvik
    
    def begin(self, hostname: str, port: int) -> bool:
        self._alvik.begin()
        return super().begin(hostname, port)
    
    def generate_unique_id(self) -> int:
        return self._player_number
    
    def on_connect(self):
        super().on_connect()
        print("[AlvikRAI] Connected")
    
    def on_disconnect(self):
        super().on_disconnect()
        print("[AlvikRAI] Disconnected")
    
    def service(self):
        self._alvik.update()
        super().service()


@dataclass
class Preferences:
    DTP_HOST: str = "127.0.0.1"
    DTP_HOST_PORT: int = 25666
    player_number: int = 1

man: Optional[AlvikRAI] = None
running = True


def main():
    global man, running
    
    print("=" * 60)
    print("Demo Alvik - TinyRPC Python Port")
    print("=" * 60)
    print()
    print("Ctrl+C to close")
    print()
    
    prefs = Preferences(
        DTP_HOST="127.0.0.1",  
        DTP_HOST_PORT=25666,
        player_number=1
    )
    
    print(f"[SYS] Configurazione:")
    print(f"      - Host: {prefs.DTP_HOST}:{prefs.DTP_HOST_PORT}")
    print(f"      - Player: {prefs.player_number}")
    print()
    
    print("[SYS] Initializing AlvikRAI...")
    
    man = AlvikRAI(player_number=prefs.player_number)
    
    if man.begin(prefs.DTP_HOST, prefs.DTP_HOST_PORT):
        print("[SYS] AlvikRAI initialized!")
    else:
        print("[SYS] AlvikRAI failed")
        return
    
    print()
    
    try:
        iteration = 0
        while running:
            man.service()
            
            if iteration % 60 == 0:
                pose = man.alvik().get_pose()
                speed = man.alvik().get_drive_speed()
                battery = man.alvik().get_battery_charge()
                connected = "✓" if man.is_connected() else "✗"
                
                print(f"[Alvik] Pos: ({pose.x:6.1f}, {pose.y:6.1f}) cm | "
                      f"θ: {math.degrees(pose.theta):5.1f}° | "
                      f"Speed: {speed.linear:5.1f} cm/s | "
                      f"🔋 {battery:.0f}% | "
                      f"DTP: {connected}")
            
            iteration += 1
            time.sleep(1.0 / 30) 
            
    except KeyboardInterrupt:
        running = False
    
    print("[SYS] Terminated.")


if __name__ == "__main__":
    main()

