#include "utils.h"
#include <Preferences.h>
#include <ArduinoJson.h>
#include <thread>


Preferences arduinoPrefs;

preferences::Preferences current {
  .WLAN_SSID = "",
  .WLAN_PASSWORD = "",
  .DTP_HOST = "",
  .DTP_HOST_PORT = 0,
  .player_number = -1
};

void preference_update_listener_task(void*);

// #define SERIAL_LISTENER_STACK 512
// StackType_t serial_listener_task_stack[SERIAL_LISTENER_STACK];
// TaskHandle_t serial_listener_task;
// StaticTask_t serial_task_buffer;
TaskHandle_t SerialUpdateTaskHandle = NULL;
std::thread serial_task;
void preferences::init() {
  arduinoPrefs.begin("alvikrai");

  //xTaskCreate(preference_update_listener_task, "preference_update_listener_task", 256, &arduinoPrefs, tskIDLE_PRIORITY, &thread_handle);
  //serial_listener_task = xTaskCreateStatic(
  //                   preference_update_listener_task,       // Function that implements the task.
  //                  "preference_update_listener_task",          // Text name for the task.
  //                   512,      // Stack size in bytes.
  //                   ( void * ) 1,    // Parameter passed into the task.
  //                   tskIDLE_PRIORITY,// Priority at which the task is created.
  //                   serial_listener_task_stack,          // Array to use as the task's stack.
  //                   &serial_task_buffer );  // Variable to hold the task's data structure.
  
  xTaskCreatePinnedToCore(
    preference_update_listener_task,         // Task function
    "preference_update_listener_task",       // Task name
    10000,             // Stack size (bytes)
    NULL,              // Parameters
    1,                 // Priority
    &SerialUpdateTaskHandle,  // Task handle
    1
  );
  

  current.WLAN_SSID = arduinoPrefs.getString("WLAN_SSID", current.WLAN_SSID);
  current.WLAN_PASSWORD = arduinoPrefs.getString("WLAN_PASSWORD", current.WLAN_PASSWORD);
  current.DTP_HOST = arduinoPrefs.getString("DTP_HOST", current.DTP_HOST);
  current.DTP_HOST_PORT = arduinoPrefs.getUShort("DTP_HOST_PORT", current.DTP_HOST_PORT);
  current.player_number = arduinoPrefs.getChar("player_number", current.player_number);
}

preferences::Preferences *preferences::get_preferences() {
  return &current;
}


void preference_update_listener_task(void* _pref) {
  // todo: use SerialEvent
  JsonDocument document;

  while ( true ) {
    auto str = Serial.readString();
    if ( str.length() == 0 ) continue;
    auto error = deserializeJson(document, str);
    auto accept = [](JsonDocument& doc) -> bool {
      return       
        doc.is<JsonObject>() &&
        doc["WLAN_SSID"].is<const char*>() &&
        doc["WLAN_PASSWORD"].is<const char*>() &&
        doc["DTP_HOST"].is<const char*>() &&
        doc["DTP_HOST_PORT"].is<unsigned short>();
    };
    if ( error) {
      Serial.println("yo mate wrong data!");
    }
    else if ( accept(document) ) {
      arduinoPrefs.putString("WLAN_SSID", document["WLAN_SSID"].as<const char*>());
      arduinoPrefs.putString("WLAN_PASSWORD", document["WLAN_PASSWORD"].as<const char*>());
      arduinoPrefs.putString("DTP_HOST", document["DTP_HOST"].as<const char*>());
      arduinoPrefs.putUShort("DTP_HOST_PORT", document["DTP_HOST_PORT"].as<unsigned short>());

      if ( document["player_number"].is<int8_t>() ) {
      arduinoPrefs.putChar("player_number", document["player_number"].as<int8_t>());


      }

      for( int i = 0; i < 6; ++i) {
        leds::green(i & 1);
        delay(500);
      }

      ESP.restart();
    }
  }

  

}


void wifi::init() {
  Serial.println("[SYS] Setting up wifi...");
  WiFi.begin(current.WLAN_SSID,current.WLAN_PASSWORD);
    do {
      Serial.println("[SYS] Connecting...");
      if ( WiFi.status() == WL_CONNECT_FAILED ) {
          Serial.println("[SYS] Connect failed :C");
          digitalWrite(LED_RED, LOW); // red
      }
      delay(100);
    }
    while ( WiFi.status() != WL_CONNECTED );
  Serial.println("[SYS] Connected!");
}