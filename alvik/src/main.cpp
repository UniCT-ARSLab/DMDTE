#include <Arduino.h>
#include <WiFi.h>
#include "utils.h"
#include "tinyrpc/tinyrpc.h"
#include <string_view>
#include <Arduino_Alvik.h>

using namespace tinyrpc;

struct Pose {
  float x,y, theta;
};
struct DriveSpeed {
  float linear, angular;
};


class AlvikRAI: public BaseRAI<AlvikRAI> {
  private:
    using Self = AlvikRAI;
  public:
    int reset_pose_count = 0;
    Arduino_Alvik &alvik() const { return _alvik; }
    AlvikRAI(){
      set_agent_identification("alvik");
      export_property<u8>({
        .name = "battery",
        .getter = []( AlvikRAI &self ) -> u8 {
          return u8(self.alvik().get_battery_charge());
        }
      });
      
      export_property<u8>({
        .name = "is_battery_charging",
        .getter = []( AlvikRAI &self ) -> u8 {
          return u8(self.alvik().is_battery_charging() > 0);
        }
      });     

      export_property<Pose>({
        .name = "pose",
        .getter = []( AlvikRAI &self ) {
          Pose pose;
          self.alvik().get_pose(pose.x, pose.y, pose.theta, CM, RAD);
          return pose;
        },
        .setter = []( AlvikRAI &self, const Pose& pose ) {
          self.alvik().reset_pose(pose.x, pose.y, pose.theta, CM, RAD);
        }
      });

      export_property<DriveSpeed>({
        .name = "drive_speed",
        .getter = []( AlvikRAI &self ) {
          DriveSpeed vel;
          self.alvik().get_drive_speed(vel.linear, vel.angular, CM_S, RAD_S);
          return vel;
        },
        .setter = [] ( AlvikRAI &self, const DriveSpeed &vel ) {
          self.alvik().drive(vel.linear, vel.angular);
        }
      });

      export_method({
        .name = "drive",
        .handler = [](AlvikRAI &self, const void *data, int size ) {
          DriveSpeed vel;
          std::memcpy(&vel, data, size);
          self.alvik().drive(vel.linear, vel.angular, CM_S, RAD_S);
        }
      });

      export_method({
        .name = "reset_pose",
        .handler = [](AlvikRAI &self, const void *data, int size ) {
          
          Pose pose;

          
          if ( size >= sizeof(Pose)) {
            std::memcpy(&pose, data, sizeof(Pose));
          }
          // Serial.printf("Ricevuta reset pose ( size: %d, expected: %d ):\n\t x: %f  y: %f theta: %f force: %d \n",
          //   size, sizeof(parameters),
          //   parameters.pose.x,
          //   parameters.pose.y,
          //   parameters.pose.theta,
          //   parameters.force
          // );
          //Pose pose { 0.0f, 0.0f, 0.0f};
          
          self.alvik().reset_pose(pose.x, pose.y, pose.theta, CM, RAD);
          //if ( parameters.force != 0 || parameters.force == 0 && self.reset_pose_count == 0 ) {
          //  auto &pose = parameters.pose;
          //}
//
          //self.reset_pose_count++;
        }
      });
    }
    bool begin(String hostname, unsigned short port)  {
      alvik().begin();
      set_player_colors();
      return BaseRAI::begin(hostname.c_str(), port);
    }
    bool begin(const char* hostname, u16 port)  {
      alvik().begin();
      return BaseRAI::begin(hostname, port);
    }
    void set_player_colors_leds(bool red, bool green, bool blue) {
          alvik().left_led.set_color(red,green,blue);
          alvik().right_led.set_color(red,green,blue);
    }
    void set_player_colors() {
      
      auto player = preferences::get_preferences()->player_number;
      switch(player) {
        case 1:
          return set_player_colors_leds(0,0,1);
        case 2:
          return set_player_colors_leds(1,0,0);
        case 3:
          return set_player_colors_leds(0,1,0);
        case 4:
          return set_player_colors_leds(1,1,0);

  }
  
}
  protected:
    void set_leds_error(bool value = true) {
      leds::green(!value);
      leds::red(value);
    }
    void on_connect() override {
      BaseRAI::on_connect();
      set_leds_error(false);
    }
    void on_disconnect() override {
      set_leds_error(true);
    }
    int generate_unique_id() const override {
      // u8 bytes[6];
      // int low;
      // WiFi.macAddress(bytes);
      // std::memcpy(&low, bytes+2, sizeof(int));
      // return low;
      return preferences::get_preferences()->player_number;
    }
  private:
    mutable Arduino_Alvik _alvik;
};


AlvikRAI man;
void setup() {
  delay(5000);
  leds::init();
  leds::builtin(true);
  serial::init();
  preferences::init();
  leds::red(true);
  wifi::init();
  leds::red(false);
  leds::blue(true);

  Serial.println("[SYS] Initializing AlvikRAI...");
  
  auto prefs = preferences::get_preferences();

  if ( man.begin(prefs->DTP_HOST, prefs->DTP_HOST_PORT) ) {
    Serial.println("[SYS] AlvikRAI initialized!");
  }
  else {
    Serial.println("[SYS] AlvikRAI failed :c");
    leds::red(true);
  }
  
  leds::blue(false);
  leds::builtin(false);
}



void loop() {
  const int update_ticks = 30;
  static int iteration = 0;
  // static u32 iteration = 0;
  // man.service();
  // if ( (iteration % 120) == 0 ) {
    man.service(iteration > update_ticks );
    iteration = iteration > update_ticks ? 0 : iteration + 1;
  // }
  // iteration++;
  delay(int(1000/float(update_ticks)));
}