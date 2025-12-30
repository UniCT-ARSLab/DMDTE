#include <Arduino.h>
#include <WiFi.h>
#include <credentials.h>

#pragma once

namespace leds {
inline void init() {
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
}
template <uint8_t LED, uint8_t ON, size_t OFF>
inline void toggle_led(bool state) {
  digitalWrite(LED, state ? ON : OFF);
};

inline void red(bool state) { toggle_led<LED_RED, LOW, HIGH>(state); }
inline void blue(bool state) { toggle_led<LED_BLUE, LOW, HIGH>(state); }
inline void green(bool state) { toggle_led<LED_GREEN, LOW, HIGH>(state); }
inline void builtin(bool state) { toggle_led<LED_BUILTIN, HIGH, LOW>(state); }

} // namespace leds

namespace preferences {
  struct Preferences {
    String WLAN_SSID;
    String WLAN_PASSWORD;
    String DTP_HOST;
    uint16_t DTP_HOST_PORT;
    int8_t player_number;
  };

  void init();
  Preferences *get_preferences();
} // namespace preferences

namespace wifi
{
  void init();
} // namespace wifi

namespace serial
{
static void init() {
  Serial.begin(115200);
  // while(!Serial.available()) {delay(1000);}
  Serial.println("[SYS] Serial ready!");
};
} // namespace serial

