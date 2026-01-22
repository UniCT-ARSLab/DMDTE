#include <enet/enet.h>
#include <tinyrpc/tinyrpc.h>
#include <tinyrpc/enet_transport.h>
namespace tinyrpc {

static std::atomic_size_t instances_using_enet = 0;
bool enet_use() {
    if ( instances_using_enet == 0 ) {
        if ( enet_initialize() < 0 ) {
            return false;
        }
    }
    instances_using_enet++;
    return true;
}
void enet_unuse() {
    instances_using_enet--;
    if ( instances_using_enet == 0 ) {
        enet_deinitialize();
    }
}

struct EnetTransport::Impl {
    EnetTransport &interface;
    std::bool is_connected{false};

    ENetHost *host;
    ENetPeer *peer;
    ENetAddress addr;
    ushort peer_id;


    Impl(EnetTransport& interface): interface(interface) {}
    ~Impl() {
        if ( host ) {
            enet_host_destroy(host);
            enet_unuse();
        }
    }

		void try_connect() {
        peer = enet_host_connect(host, &addr, 2, peer_id);
		}

    bool begin(const char* hostname, ushort port) {
        if ( !enet_use() ) return false;

        enet_address_set_host(&addr, hostname.data());
        addr.port = port;

        host = enet_host_create(nullptr, 1, PROTO_NUM_CHANNELS, 0, 0);

        if ( host == nullptr ) return false;

        peer_id = interface.generate_unique_id();

				try_connect();

        return true;
    }

    void service(std::function<void(const TransportEvent&)> eventFn) {
        ENetEvent event;
				TransportEvent transportEvent;
        while ( enet_host_service(host,&event,0) > 0 ) {
            switch (event.type) {
                case ENET_EVENT_TYPE_NONE: return;
                case ENET_EVENT_TYPE_CONNECT: {
                    is_connected = true;
                    transportEvent = TransportEvent {
											.type = TransportEvent::EventConnected,
											.data = nullptr,
											.dat_size = 0
										};
										eventFn(transportEvent);

                    break;
                }
                case ENET_EVENT_TYPE_DISCONNECT: {
                    is_connected = true;
                    transportEvent = TransportEvent {
											.type = TransportEvent::EventDisconnected,
											.data = nullptr,
											.dat_size = 0
										};
										eventFn(transportEvent);

                    try_connect();
                    break;
                }
                case ENET_EVENT_TYPE_RECEIVE: {
 										transportEvent = TransportEvent {
											.type = TransportEvent::EventMessage,
											.data = event.packet->data,
											.dat_size = event.packet->dataLength
										};
										eventFn(transportEvent);
                    enet_packet_destroy(event.packet);

										break;
                }

            }
        }
    }
    void send_message(const uint8_t* data, ushort size, bool reliable = false) {


        ushort flags = ENET_PACKET_FLAG_NO_ALLOCATE;
        if ( reliable ) flags |= ENET_PACKET_FLAG_RELIABLE;
        ushort channel = reliable
            ? PROTO_RELIABLE_CHANNEL
            : PROTO_UNRELIABLE_CHANNEL;

        auto packet = enet_packet_create(data, size, flags);
        enet_peer_send(peer, channel, packet);
        enet_host_flush(host);
    }
};


bool EnetTransport::begin(const char* hostname, ushort port) {
    return impl->begin(hostname, port);
}

void EnetTransport::send_message(const uint8_t* data, uint size, bool reliable) {
    impl->send_message(data, size, reliable);
}
void EnetTransport::service(std::function<void(const TransportEvent&)> eventFn) {
    impl->service(eventFn);
}
bool EnetTransport::is_connected() const {
    return impl->is_connected;
}

EnetTransport::EnetTransport() {
    impl = std::make_unique<Impl>(*this);
};
EnetTransport::~EnetTransport() = default;

}