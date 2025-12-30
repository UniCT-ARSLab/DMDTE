#include <iot_board.h>
#include <WiFi.h>
#include <tinyrpc.h>

using namespace tinyrpc;
bool dtpConnected = false;
class SemaforoRAI : public BaseRAI<SemaforoRAI>
{

public:
    uint8_t led_rosso = 0;
    uint8_t led_giallo = 0;
    uint8_t led_verde = 0;

    SemaforoRAI()
    {
        set_agent_identification("semaforo");
        export_property<uint8_t>({.name = "led_rosso",
                                  .getter = [](SemaforoRAI &self)
                                  { return self.led_rosso; },
                                  .setter = [](SemaforoRAI &self, const uint8_t &newval)
                                  { self.led_rosso = newval; }});

        export_property<uint8_t>({.name = "led_giallo",
                                  .getter = [](SemaforoRAI &self)
                                  { return self.led_giallo; },
                                  .setter = [](SemaforoRAI &self, const uint8_t &newval)
                                  { self.led_giallo = newval; }});

        export_property<uint8_t>({.name = "led_verde",
                                  .getter = [](SemaforoRAI &self)
                                  { return self.led_verde; },
                                  .setter = [](SemaforoRAI &self, const uint8_t &newval)
                                  { self.led_verde = newval; }});
    }

    protected:

    void on_connect(){
        BaseRAI::on_connect();
        dtpConnected = true;

    }
};

SemaforoRAI digitaltwin;

TaskHandle_t Task1;
TaskHandle_t Task2;



void taskDTP(void *pvParameters)
{
    digitaltwin.begin("192.168.1.4", 25666);

    while (1)
    {
        digitaltwin.service();
        delay(int(1000 / 30));
    }
}

void taskLed(void *pvParameters)
{

    while (1)
    {
        digitalWrite(LED_RED, HIGH);
        digitalWrite(LED_YELLOW, LOW);
        digitalWrite(LED_GREEN, LOW);

        digitaltwin.led_rosso = 1;
        digitaltwin.led_giallo = 0;
        digitaltwin.led_verde = 0;
        delay(2000);

        digitalWrite(LED_RED, LOW);
        digitalWrite(LED_YELLOW, HIGH);
        digitalWrite(LED_GREEN, LOW);
        digitaltwin.led_rosso = 0;
        digitaltwin.led_giallo = 1;
        digitaltwin.led_verde = 0;
        delay(2000);

        digitalWrite(LED_RED, LOW);
        digitalWrite(LED_YELLOW, LOW);
        digitalWrite(LED_GREEN, HIGH);
        digitaltwin.led_rosso = 0;
        digitaltwin.led_giallo = 0;
        digitaltwin.led_verde = 1;
        delay(2000);
    }
}

void setup()
{
    IoTBoard::init_serial();
    IoTBoard::init_leds();
    IoTBoard::init_buttons();

    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin("ARSLab-IoT_2G", "arslabiot");
    Serial.println("Provo a collegarmi...");

    while (WiFi.status() != WL_CONNECTED)
    {
        Serial.print(".");
        digitalWrite(LED_RGB_B, HIGH);
        delay(100);
        digitalWrite(LED_RGB_B, LOW);
        delay(100);
    }
    

    Serial.println("Connesso");

    digitalWrite(LED_RGB_B, HIGH);

    xTaskCreatePinnedToCore(
        taskDTP, "DTP Task" // A name just for humans
        ,
        8196 // The stack size can be checked by calling `uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL);`
        ,
        NULL // Task parameter which can modify the task behavior. This must be passed as pointer to void.
        ,
        2 // Priority
        ,
        &Task1 // Task handle is not used here - simply pass NULL
        ,
        0 // Core on which the task will run
    );

    xTaskCreatePinnedToCore(
        taskLed, "LED Task" // A name just for humans
        ,
        2048 // The stack size can be checked by calling `uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL);`
        ,
        NULL // Task parameter which can modify the task behavior. This must be passed as pointer to void.
        ,
        1 // Priority
        ,
        &Task2 // Task handle is not used here - simply pass NULL
        ,
        1 // Core on which the task will run
    );
}

void loop()
{
    // put your main code here, to run repeatedly:
}
