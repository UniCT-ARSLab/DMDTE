#ifdef __linux__

#include "../tinydtp.h"
#pragma once
namespace tinydtp {

/**
 * Implementation of Unix Domain Socket transport for tinydtp, only available on linux atm
 */	
class UDSTransport : public Transport {
public:
	UDSTransport(std::string_view path);
	~UDSTransport();
	size_t get_maximum_packet_size() const override { return 4096; };
  size_t send_message(const std::uint8_t *pkt, const size_t size, TransportQuality transport_quality = TransportQuality::None ) override;
  size_t service() override;

  virtual bool is_connected() const override;
	
private:
	struct Impl;
	friend class Impl;
	std::unique_ptr<Impl> impl;
};

}
#endif