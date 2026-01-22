#include <memory>
#include <functional>
#include <cstdint>
#pragma once

namespace tinyrpc{ 
	struct TransportEvent;
	class EnetTransport {
  public:
    EnetTransport();
    ~EnetTransport();
    bool begin(const char* hostname, ushort port);

    bool is_connected();
    void send_message(const uint8_t* data, size_t size, bool reliable = false);
    void service(std::function<void(const TransportEvent&)> eventFn);
			
	private:
    struct Impl;
    std::unique_ptr<Impl> impl;

	};
}