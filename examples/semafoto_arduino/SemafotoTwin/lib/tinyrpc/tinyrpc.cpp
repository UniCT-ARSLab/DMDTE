#include "tinyrpc.h"
#include <atomic>

#include <memory>
#include <mutex>
#include <string_view>
#include <enet/enet.h>


using namespace tinyrpc;
enum {
    PROTO_RELIABLE_CHANNEL = 0,
    PROTO_UNRELIABLE_CHANNEL = 1,
    PROTO_NUM_CHANNELS
};


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


struct ClientAbstraction::Impl {
    ClientAbstraction &interface;
    std::recursive_mutex mutex;
    std::atomic_bool is_connected{false};

    ENetHost *host;
    ENetPeer *peer;
    ENetAddress addr;
    u32 peer_id;


    Impl(ClientAbstraction& interface): interface(interface) {}
    ~Impl() {
        if ( host ) {
            enet_host_destroy(host);
            enet_unuse();
        }
    }

    void _try_connect() {
        peer = enet_host_connect(host, &addr, 2, peer_id);
    }
    bool begin(std::string_view hostname, u16 port) {
        if ( !enet_use() ) return false;

        enet_address_set_host(&addr, hostname.data());
        addr.port = port;

        host = enet_host_create(nullptr, 1, PROTO_NUM_CHANNELS, 0, 0);

        if ( host == nullptr ) return false;

        peer_id = interface.generate_unique_id();

        _try_connect();

        return true;
    }

    void service() {
        std::lock_guard lk(mutex);
        enet_service();
    }

    void enet_service() {
        ENetEvent event;
        while ( enet_host_service(host,&event,0) > 0 ) {
            switch (event.type) {
                case ENET_EVENT_TYPE_NONE: return;
                case ENET_EVENT_TYPE_CONNECT: {
                    is_connected = true;
                    interface.on_connect();
                    break;
                }
                case ENET_EVENT_TYPE_DISCONNECT: {
                    is_connected = false;
                    interface.on_disconnect();

                    _try_connect();
                    break;
                }
                case ENET_EVENT_TYPE_RECEIVE: {

                    auto data = event.packet->data;
                    auto length = event.packet->dataLength;
                    interface.on_message(data, length);
                    enet_packet_destroy(event.packet);
                }

            }
        }
    }
    void send_message(const u8* data, u32 size, bool reliable = false) {

        std::lock_guard lk(mutex);

        u32 flags = ENET_PACKET_FLAG_NO_ALLOCATE;
        if ( reliable ) flags |= ENET_PACKET_FLAG_RELIABLE;
        u32 channel = reliable
            ? PROTO_RELIABLE_CHANNEL
            : PROTO_UNRELIABLE_CHANNEL;

        auto packet = enet_packet_create(data, size, flags);
        enet_peer_send(peer, channel, packet);
        enet_host_flush(host);
    }
};

bool ClientAbstraction::begin(std::string_view hostname, u16 port) {
    return impl->begin(hostname, port);
}

void ClientAbstraction::send_message(const u8* data, u32 size, bool reliable) {
    impl->send_message(data, size, reliable);
}
void ClientAbstraction::service() {
    impl->service();
}
bool ClientAbstraction::is_connected() const {
    return impl->is_connected;
}
int ClientAbstraction::generate_unique_id() const {
    std::srand(std::time(nullptr));
    return rand();
}

ClientAbstraction::ClientAbstraction() {
    impl = std::make_unique<Impl>(*this);
};
ClientAbstraction::~ClientAbstraction() = default;
