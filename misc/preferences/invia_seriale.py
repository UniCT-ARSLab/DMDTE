#!/usr/bin/env python3
# sì è stato fatto de gemini
import serial
import argparse
import os
import sys
import time # perché cavolo ha importato time se non lo usa???

def main():
    # Configurazione degli argomenti da riga di comando
    parser = argparse.ArgumentParser(description="Invia un file binario o di testo a un dispositivo seriale.")
    
    parser.add_argument(
        "-d", "--device", 
        required=True, 
        help="Il dispositivo seriale (es. /dev/ttyUSB0, /dev/ttyACM0)"
    )
    
    parser.add_argument(
        "-b", "--baud", 
        type=int, 
        default=115200, 
        help="Velocità in baud (default: 115200)"
    )
    
    parser.add_argument(
        "file", 
        help="Il percorso del file da inviare"
    )

    args = parser.parse_args()

    # Verifica esistenza file
    if not os.path.exists(args.file):
        print(f"❌ Errore: Il file '{args.file}' non esiste.")
        sys.exit(1)

    print(f"🔌 Connessione a {args.device} @ {args.baud} baud...")

    try:
        # Apertura porta seriale
        # timeout=1 impedisce al programma di bloccarsi per sempre se qualcosa va storto
        ser = serial.Serial(args.device, args.baud, timeout=1, write_timeout=2)
        
        # Opzionale: attendere un attimo che il dispositivo si resetti (comune con Arduino)
        # time.sleep(2) 

        if ser.is_open:
            print(f"✅ Porta aperta. Preparazione invio file: {args.file}")
            
            file_size = os.path.getsize(args.file)
            bytes_sent = 0
            chunk_size = 1024 # Dimensione del blocco di invio (byte)

            with open(args.file, 'rb') as f:
                while True:
                    chunk = f.read(chunk_size)
                    if not chunk:
                        break
                    
                    # Invio dati
                    ser.write(chunk)
                    bytes_sent += len(chunk)
                    
                    # Semplice barra di progresso testuale
                    percent = (bytes_sent / file_size) * 100
                    sys.stdout.write(f"\r📤 Invio in corso: {percent:.1f}% ({bytes_sent}/{file_size} bytes)")
                    sys.stdout.flush()

            ser.flush() # Attende che tutti i dati siano fisicamente usciti dal buffer
            print(f"\n✅ Trasferimento completato!")
            
        ser.close()

    except serial.SerialException as e:
        print(f"\n❌ Errore Seriale: {e}")
        print("Suggerimento: Controlla che il dispositivo sia corretto e di avere i permessi (es. sudo o gruppo dialout).")
    except OSError as e:
        print(f"\n❌ Errore I/O File: {e}")
    except KeyboardInterrupt:
        print("\n⚠️ Interrotto dall'utente.")
        if 'ser' in locals() and ser.is_open:
            ser.close()
        sys.exit(0)

if __name__ == "__main__":
    main()