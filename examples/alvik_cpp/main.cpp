#include <thread>
#include <string>
#include <memory>
#include <print>

#include <cmath>

#include "argparse.hpp"
#include "tinydtp/tinydtp.h"
#include "tinydtp/transports/enet.h"
#include "tinydtp/transports/uds.h"

using namespace tinydtp;

struct Pose {
  float x,y, theta;
};

struct DriveSpeed {
  float linear, angular;
};


class AlvikRai: public TinyDTP {
public:

  Property<int> battery {create_property<int>()};
  Property<Pose> pose {create_property<Pose>()};
  Property<DriveSpeed> drive_speed {create_property<DriveSpeed>()};
  
  AlvikRai () : TinyDTP() {
  }
  
  void setup() {
    set_name("FakeAlvik");
    set_uuid(utils::uuid_to_bytes("7e906a46-e425-4348-ba3c-e5b66b295dda"));
    //set_uuid({ 0x19,0x89,0x91,0x4b,0x19,0xde,0x4f,0xc6,0xa5,0x93,0xd6,0x65,0x29,0x0e,0x43,0x05});
    set_property(battery, 100);
    set_property(pose, { 0.0f,0.0f,0.0f });
    set_property(drive_speed, {0.0f,0.0f});
    
  }
  void loop(float dt) {
    auto pose_ = get_property(pose);
    auto speeds_ = get_property(drive_speed);
		
    auto theta = pose_.theta += speeds_.angular * dt;
    auto ix = std::cosf(theta) * speeds_.linear * dt;
		auto iy = std::sinf(theta) * speeds_.linear * dt;
		pose_.x += ix;
		pose_.y += iy;

    set_property(pose, pose_);

  }


  protected:
  void on_connection_state_change(bool connected) override {
    if ( connected ) {
      std::println("Connesso! 😁");
    }
    else {
      std::println("Disconnesso! 😥");
    }
  }


};

int main(int argc, const char **argv) {
  
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
  
  //ENetTransport transport(host, port);
  UDSTransport transport("/home/marco/dtp.sock");
	auto instance = AlvikRai();
  instance.finalize(&transport);
  instance.setup();

  auto loop = std::thread([&](){
		const float dt = 60 / 60.0f;
		const auto dt_seconds  = std::chrono::duration<float>(dt);

		for(;;) {
			instance.loop(dt);
      instance.service();

			std::this_thread::sleep_for(dt_seconds);
		}
	});
  loop.join();
	return 0;
}