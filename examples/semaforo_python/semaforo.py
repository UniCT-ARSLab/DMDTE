import time
import threading
import sys
from tinyrpc import BaseRAI, PropertyDescriptor


class SemaforoRAI(BaseRAI):

    def __init__(self):
        super().__init__()
        
        self.led_rosso: int = 0
        self.led_giallo: int = 0
        self.led_verde: int = 0
        
        self.set_agent_identification("semaforo")
        
        self.export_property(PropertyDescriptor(
            name="led_rosso",
            type_name="uint8",
            getter=lambda self: self.led_rosso,
            setter=lambda self, v: setattr(self, 'led_rosso', v)
        ))
        
        self.export_property(PropertyDescriptor(
            name="led_giallo",
            type_name="uint8",
            getter=lambda self: self.led_giallo,
            setter=lambda self, v: setattr(self, 'led_giallo', v)
        ))
        
        self.export_property(PropertyDescriptor(
            name="led_verde",
            type_name="uint8",
            getter=lambda self: self.led_verde,
            setter=lambda self, v: setattr(self, 'led_verde', v)
        ))

 


digitaltwin = SemaforoRAI()
running = True


def task_dtp():
    global running
    
    SERVER_HOST = "127.0.0.1"
    SERVER_PORT = 25666
    
    print(f"[DTP Task] Connessione a {SERVER_HOST}:{SERVER_PORT}...")
    
    if not digitaltwin.begin(SERVER_HOST, SERVER_PORT):
        print("[DTP Task] Errore: impossibile inizializzare la connessione")
        sys.exit(1)
        return
    
    print("[DTP Task] Inizializzazione completata, in attesa di connessione...")
    
    while running:
        digitaltwin.service()
        time.sleep(1.0 / 30)  # ~30 FPS


def task_led():
    global running
    
    while running:
        print_led_state("ROSSO", True, False, False)
        digitaltwin.led_rosso = 1
        digitaltwin.led_giallo = 0
        digitaltwin.led_verde = 0
        time.sleep(2.0)
        
        if not running:
            break
        
        print_led_state("GIALLO", False, True, False)
        digitaltwin.led_rosso = 0
        digitaltwin.led_giallo = 1
        digitaltwin.led_verde = 0
        time.sleep(2.0)
        
        if not running:
            break
        
        print_led_state("VERDE", False, False, True)
        digitaltwin.led_rosso = 0
        digitaltwin.led_giallo = 0
        digitaltwin.led_verde = 1
        time.sleep(2.0)


def print_led_state(color: str, rosso: bool, giallo: bool, verde: bool):
    r = "🔴" if rosso else "⚫"
    g = "🟡" if giallo else "⚫"
    v = "🟢" if verde else "⚫"
    connected = "OK" if digitaltwin.is_dtp_connected() else "NOT CONNECTION"
    print(f"[Semaphore] {r} {g} {v} - State: {color} - DTP: {connected}")


def main():
    global running
    
    print("=" * 50)
    print("Demo Semaforo - DTP Python Port")
    print("=" * 50)
    print()
    print("Ctrl+C to close")
    print()
    
    dtp_thread = threading.Thread(target=task_dtp, name="DTP Task", daemon=True)
    led_thread = threading.Thread(target=task_led, name="LED Task", daemon=True)
    
    dtp_thread.start()
    led_thread.start()
    
    try:
        while running:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n\nClosing...")
        running = False
        
    dtp_thread.join(timeout=1.0)
    led_thread.join(timeout=1.0)


if __name__ == "__main__":
    main()
