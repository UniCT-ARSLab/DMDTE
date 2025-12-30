#include <iot_board.h>
#include <WiFi.h>
#include <tinyrpc.h>




using namespace tinyrpc;
bool dtpConnected = false;


#define XBEE_POSE  0x0010

typedef struct {
    uint16_t checksum;
    uint16_t packet_type;
    uint8_t payload[128];
}  __attribute__((packed)) t_xbee_packet;

typedef struct {
    float x, y, theta;
} t_pose;

struct Pose {
  float x,y, theta;
};

class RobotEurobotRAI : public BaseRAI<RobotEurobotRAI>
{

public:
    Pose pose;

    RobotEurobotRAI()
    {
        set_agent_identification("robot_eurobot");
        export_property<Pose>({.name = "pose",
                                  .getter = [](RobotEurobotRAI &self)
                                  { return self.pose; },
                                  .setter = [](RobotEurobotRAI &self, const Pose &newval)
                                  { self.pose = newval; }});
    }

protected:
    void on_connect()
    {
        BaseRAI::on_connect();
        dtpConnected = true;
    }
};

RobotEurobotRAI digitaltwin;

t_xbee_packet packetReceived;

TaskHandle_t Task1;
TaskHandle_t Task2;

void taskDTP(void *pvParameters)
{
    digitaltwin.begin("192.168.1.5", 25666);

    while (1)
    {
        digitaltwin.service();
        delay(int(1000 / 30));
    }
}

void taskZigbee(void *pvParameters)
{
    Pose aux;

    while (1)
    {
        if(zigbee->receivePacket()){
            display->clearDisplay();
            display->setCursor(0,0);
            
            zigbee->readBytes((uint8_t *)&packetReceived, sizeof(t_xbee_packet));
            display->printf("Ricevo : T = %x\n", packetReceived.packet_type);
            memcpy(&(aux), packetReceived.payload, sizeof(Pose));
            digitaltwin.pose.x = (aux.y / 10.0) ;
            digitaltwin.pose.y = (aux.x / 10.0) * -1;
            digitaltwin.pose.theta = aux.theta;
           
            display->printf("X: %f, Y: %f, A: %f\n", digitaltwin.pose.x, digitaltwin.pose.y, digitaltwin.pose.theta);
            display->display();
            
        }
       
        delay(1);
    }
}

void setup()
{
    IoTBoard::init_serial();
    IoTBoard::init_leds();
    IoTBoard::init_buttons();
    IoTBoard::init_display();
    IoTBoard::init_spi();

    IoTBoard::init_zigbee();
    zigbee->setAddress(0x3);
    zigbee->setPanId(0xbabe);
    zigbee->setChannel(12);
    zigbee->setPromiscuous(true);

    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin("ARSLab-IoT_2G", "arslabiot");
    Serial.println("Provo a collegarmi...");

    while (WiFi.status() != WL_CONNECTED)
    {
        display->print(".");
        digitalWrite(LED_RGB_B, HIGH);
        delay(100);
        digitalWrite(LED_RGB_B, LOW);
        delay(100);
        display->display();
    }

    display->println("Connesso");
    display->display();

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
        taskZigbee, "Zigbee Task" // A name just for humans
        ,
        8196 // The stack size can be checked by calling `uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL);`
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
}
