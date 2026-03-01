#include <atomic>
#include <enet/enet.h>

#include "enet.h"

using namespace tinydtp;

static std::atomic_size_t instances_using_enet = 0;
bool enet_use() {
  if (instances_using_enet == 0) {
    if (enet_initialize() < 0) {
      return false;
    }
  }
  instances_using_enet++;
  return true;
}

void enet_unuse() {
  instances_using_enet--;
  if (instances_using_enet == 0) {
    enet_deinitialize();
  }
}

struct ENetTransport::Impl {
  ENetTransport &parent;
  ENetHost *host;
  ENetPeer *peer;
  ENetAddress addr;
  bool connected = false;
  bool is_trying_to_connect = false;

  Impl(ENetTransport &parent, std::string_view hostname, std::uint16_t port)
      : parent(parent) {
    enet_use();
    enet_address_set_host(&addr, hostname.data());
    addr.port = port;
    host = enet_host_create(nullptr, 1, 2, 0, 0);
  }

  ~Impl() { enet_unuse(); }

  void try_connect() {
    is_trying_to_connect = true;
    peer = enet_host_connect(host, &addr, 2, 0);
  }
  size_t service() {
    if (connected == false && is_trying_to_connect == false) {
      try_connect();
    } else {
			service_do_service();
    }

    return 0;
  }
  void service_do_service() {
    ENetEvent event;
    while (enet_host_service(host, &event, 0) > 0) {
      switch (event.type) {
      case ENET_EVENT_TYPE_NONE:
        return;
      case ENET_EVENT_TYPE_CONNECT: {
				is_trying_to_connect = false;
        parent.on_connection_state_change(connected = true);
        break;
      }
      case ENET_EVENT_TYPE_DISCONNECT: {
				is_trying_to_connect = false;
        parent.on_connection_state_change(connected = false);

        try_connect();
        break;
      }
      case ENET_EVENT_TYPE_RECEIVE: {

        auto data = event.packet->data;
        auto length = event.packet->dataLength;
        parent.on_message(data, length);
        enet_packet_destroy(event.packet);
      }
      }
    }
  } 
  size_t send_message(const std::uint8_t *pkt, const size_t size, TransportQuality transport_quality) {
		int channel = 0;
		std::uint32_t flags = 0;
    if ( (transport_quality & TransportQuality::Reliable) != TransportQuality::None ) {
			flags |= ENET_PACKET_FLAG_RELIABLE;
			channel = 1;
		}
    
   	auto packet = enet_packet_create(pkt, size, flags);
    enet_peer_send(peer, channel, packet);
    enet_host_flush(host);
		return 0;
  };
};

ENetTransport::ENetTransport(std::string_view hostname, std::uint16_t port) {
  impl = std::make_unique<Impl>(*this, hostname, port);
}
size_t ENetTransport::send_message(const std::uint8_t *pkt, const size_t size,
                                   TransportQuality transport_quality) {
  return impl->send_message(pkt, size, transport_quality);
};
size_t ENetTransport::service() { return impl->service(); };

bool ENetTransport::is_connected() const { return impl->connected; }