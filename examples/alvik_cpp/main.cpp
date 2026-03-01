#include <thread>
#include <string>
#include <memory>
#include <print>

#include <cmath>

#include "argparse.hpp"
#include "tinydtp/tinydtp.h"

using namespace tinydtp;

class BlankTransport : public Transport {
public:
  size_t send_message(const std::uint8_t *pkt, const size_t size, TransportQuality transport_quality) override {
    std::cout << "Sending packet of size " << size << std::endl;
    return size;
  }
  size_t service() override {
    tinydtp::internals::Message fake;
    fake.msgty = tinydtp::internals::MessageType::Ping;
    on_message(internals::as_bytes(&fake), sizeof(fake));
    return 0;
  }
};

class AlvikRai: public TinyDTP {
public:
  Property<int> battery {create_property<int>()};
  //Property<std::array<float, 3>> position {create_property<std::array<float, 3>>()};

  AlvikRai () : TinyDTP() {
    
  }

};

int main(int argc, const char **argv) {
  BlankTransport transport;
	auto instance = AlvikRai();
  instance.finalize(&transport);
  instance.service(true);

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

	

	// auto loop = std::thread([&](){
	// 	const float dt = 1.0f / 60.0f;
	// 	const auto dt_seconds  = std::chrono::duration<float>(dt);
// 
	// 	std::println("dt: {0}", dt);
	// 	for(;;) {
	// 		instance->integrate(dt);
	// 		instance->service();
// 
	// 		std::this_thread::sleep_for(dt_seconds);
	// 	}
	// });
// 
	// loop.join();

	return 0;
}