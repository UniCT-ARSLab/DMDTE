#include <thread>
#include <string>
#include <memory>
#include <print>

#include <cmath>

#include "argparse.hpp"
#include "tinyrpc/tinyrpc.h"

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
		uint8_t player_number = -1;
		uint8_t battery_charge = 80;
		bool is_battery_charging = true;
    int reset_pose_count = 0;
		Pose pose;
		DriveSpeed drive_speed;

    AlvikRAI(){
      set_agent_identification("alvik");
      export_property<u8>({
        .name = "battery",
        .getter = []( AlvikRAI &self ) -> u8 {
          return self.battery_charge;
        }
      });
      
      export_property<u8>({
        .name = "is_battery_charging",
        .getter = []( AlvikRAI &self ) -> u8 {
          return self.is_battery_charging;
        }
      });     

      export_property<Pose>({
        .name = "pose",
        .getter = []( AlvikRAI &self ) {
          
          return self.pose;
        },
        .setter = []( AlvikRAI &self, const Pose& pose ) {
          self.pose = pose;
        }
      });

      export_property<DriveSpeed>({
        .name = "drive_speed",
        .getter = []( AlvikRAI &self ) {
					return self.drive_speed;
        }
      });

      export_method({
        .name = "drive",
        .handler = [](AlvikRAI &self, const void *data, int size ) {
          DriveSpeed vel;
          std::memcpy(&vel, data, size);
          self.drive_speed = vel;
        }
      });

      export_method({
        .name = "reset_pose",
        .handler = [](AlvikRAI &self, const void *data, int size ) {
          
          struct {
            Pose pose{ 0.0f, 0.0f, 0.0f};
            int force{1};
          } parameters;

          
          if ( size == sizeof(parameters)) {
            std::memcpy(&parameters, data, sizeof(parameters));
          }
          // Serial.printf("Ricevuta reset pose ( size: %d, expected: %d ):\n\t x: %f  y: %f theta: %f force: %d \n",
          //   size, sizeof(parameters),
          //   parameters.pose.x,
          //   parameters.pose.y,
          //   parameters.pose.theta,
          //   parameters.force
          // );
          //Pose pose { 0.0f, 0.0f, 0.0f};
          
          if ( parameters.force != 0 || parameters.force == 0 && self.reset_pose_count == 0 ) {
            auto &pose = parameters.pose;
            self.pose = pose;
          }

          self.reset_pose_count++;
        }
      });
    }
    bool begin(std::string hostname, unsigned short port)  {
      // alvik().begin();
      return BaseRAI::begin(hostname.c_str(), port);
    }
    bool begin(const char* hostname, u16 port)  {
      return BaseRAI::begin(hostname, port);
    }

		void integrate(float dt) {
			auto theta = pose.theta += drive_speed.angular * dt;

			auto ix = std::cosf(theta) * drive_speed.linear * dt;
			auto iy = std::sinf(theta) * drive_speed.linear * dt;

			pose.x += ix;
			pose.y += iy;
			
		}
  protected:
    
    void on_connect() override {
      BaseRAI::on_connect();
			std::println("Connected!");
      //set_leds_error(false);
    }
    void on_disconnect() override {
			std::println("Disconnected!");
      // set_leds_error(true);
    }
    int generate_unique_id() const override {
      return player_number;
    }
};


int main(int argc, const char **argv) {
	auto instance = std::make_unique<AlvikRAI>();
	
	auto ap = argparse::ArgumentParser(argv[0], "0.1");
	ap.add_argument("--host")
		.help("Address of DTP host")
		.default_value("127.0.0.1");
	ap.add_argument("--port")
		.help("Port where DTP host listens")
		.scan<'i', uint16_t>()
		.default_value<uint16_t>(25666);
	ap.add_argument("--player")
		.help("Player number")
		.scan<'i', uint8_t>()
		.default_value<uint8_t>(1);
	
	ap.parse_args(argc, argv);
	
	
	const auto host = ap.get<std::string>("host");
	const auto port = ap.get<uint16_t>("port");
	const auto player_number =  ap.get<uint8_t>("player");

	instance->player_number = player_number;
	
	instance->begin(host.c_str(), port);

	auto loop = std::thread([&](){
		const float dt = 1.0f / 60.0f;
		const auto dt_seconds  = std::chrono::duration<float>(dt);

		std::println("dt: {0}", dt);
		for(;;) {
			instance->integrate(dt);
			instance->service();

			std::this_thread::sleep_for(dt_seconds);
		}
	});

	loop.join();

	return 0;
}