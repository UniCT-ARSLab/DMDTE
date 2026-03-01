#ifdef __linux__

#include <sys/socket.h>
#include <sys/un.h>
#include "uds.h"
using namespace tinydtp;

struct UDSTransport::Impl {
	UDSTransport &parent;
	std::string path;
	int sock_fd = -1;
	bool connected = false;
	struct sockaddr_un addr;
	std::uint8_t buffer[4096];
	Impl(UDSTransport &parent,std::string_view path_): parent(parent), path(path_) {
		std::memset(&addr, 0, sizeof(struct sockaddr_un));
		addr.sun_family = AF_UNIX;
		std::strncpy(addr.sun_path, path.data(), sizeof(addr.sun_family)-1);
	}

	size_t service() {
		if ( connected ) {
			service_do_connect();
		}
		else {
			service_do_data();
		}
		return 0;
	}
	void service_do_connect() {
		if ( sock_fd == -1 ) {
			sock_fd = socket(AF_UNIX, SOCK_STREAM, 0);
			if ( sock_fd == -1 ) {
				connected = false;
				parent.on_connection_state_change(connect);
				return;
			}
		}
		
		if ( connect(sock_fd, (struct sockaddr* )&addr, sizeof(struct sockaddr_un) ) == -1 ) {
			connected = false;
		}
		else {
			connected = true;
		}
		parent.on_connection_state_change(connect);

		

	}

	void service_do_data() {
		ssize_t size = recv(sock_fd, buffer, sizeof(buffer), 0 );
		if ( size < 0 ) {
			connected = false;
			parent.on_connection_state_change(connected);
		}

		parent.on_message(buffer, size);
	}

  size_t send_message(const std::uint8_t *pkt, const size_t size) {
		if ( !connected ) {
			return 0;
		}
		ssize_t sent = send(sock_fd, pkt, size, MSG_NOSIGNAL);
		if ( sent < 0 ) {
			connected = false;
			parent.on_connection_state_change(false);
			return 0;
		}
		return sent;
	};
};

UDSTransport::UDSTransport(std::string_view path) {
	impl = std::make_unique<Impl>(*this, path);
}

UDSTransport::~UDSTransport() {}
size_t UDSTransport::send_message(
    const std::uint8_t *pkt, const size_t size,
    TransportQuality transport_quality) {
		return impl->send_message(pkt, size);

};
size_t UDSTransport::service() {
	return impl->service();
};

bool UDSTransport::is_connected() const {
	return impl->connected;
}

#endif