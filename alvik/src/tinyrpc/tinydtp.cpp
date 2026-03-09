#include "tinydtp.h"

namespace tinydtp {
void Transport::bind_dtp(TinyDTP *tinydtp) {
  this->tinydtp = tinydtp;
}
  void Transport::on_connection_state_change(bool connected) {
    tinydtp->on_connection_state_change(connected);
  }

void Transport::on_message(const std::uint8_t *data, size_t len) {
  tinydtp->on_message(data, len);
} 

int TinyDTP::finalize(Transport *transport) {
	bind_transport(transport);
  size_t size = compute_backing_data_size();
  message_buffer.reserve(std::min(size, transport->get_maximum_packet_size()) + sizeof(internals::MessageData::FieldData) * props.size() + sizeof(internals::MessageData) + sizeof(internals::Message));
  action_buffer.reserve(transport->get_maximum_packet_size());
  backing_data = new std::uint8_t[size];
  if (backing_data == nullptr) {
    return -1;
  }
  assign_backing_data_storate_pointers_to_properties();
  return 0;
}
void TinyDTP::dispatch(std::uint32_t action, const std::uint8_t *data,
              const size_t data_len) {
  using namespace internals;
  std::lock_guard lock(action_buffer_loc);
  const size_t header_size = sizeof(Message) + sizeof(MessageAction);
  const size_t max_data_len = transport->get_maximum_packet_size() - header_size;
  action_buffer.resize(header_size);
  auto message = reinterpret_cast<Message*>(action_buffer.data());
  message->msgty = MessageType::Action;
  message->content[0].action.action = action;
  action_buffer.insert(action_buffer.end(), data, data + std::min(data_len, max_data_len));
  
  message->size = action_buffer.size();
  transport->send_message(action_buffer.data(), action_buffer.size(), TransportQuality::Reliable);
  
}

void TinyDTP::service(bool full_update) {
   send_update_data(full_update);
   transport->service();
}

void TinyDTP::dispose_backing_data() {
    if (backing_data != nullptr) {
      delete backing_data;
    }
  }
  size_t TinyDTP::compute_backing_data_size() {
    size_t size = 0;
    for (auto &prop : props) {
      size += prop.size;
    }
    return size;
  }
  void TinyDTP::assign_backing_data_storate_pointers_to_properties() {
    size_t offset = 0;
    for (auto &prop : props) {
      prop.backing_data = backing_data + offset;
      offset += prop.size;
    }
  }

  

  void TinyDTP::send_update_data_message(std::vector<uint8_t> &data, size_t fields_count, TransportQuality transport_quality) {
    using namespace internals;
    auto as_message = reinterpret_cast<internals::Message*>(data.data());
    as_message->msgty = MessageType::Data;
    as_message->size = std::uint16_t(data.size());
    as_message->content[0].data.count = std::uint8_t(fields_count);
    transport->send_message(data.data(), data.size(), transport_quality);
  }

  /**
   * Sends update data to the other DTP end, takes into account the transport's limit packet size!
   */
  void TinyDTP::send_update_data(bool full_update) {
    if (!transport->is_connected()) return;
    std::lock_guard lock_props(properties_lock);
    std::lock_guard lock_buffer(message_buffer_lock);
    using namespace internals;
    auto &buffer = message_buffer;
    const auto transport_quality = full_update ? TransportQuality::Reliable : TransportQuality::None;
    const size_t max_packet_size = transport->get_maximum_packet_size();
    const size_t header_size = sizeof(Message) + sizeof(MessageData);
    const size_t field_header_size = sizeof(MessageData::FieldData);
    const size_t max_field_size = max_packet_size - header_size;

    buffer.resize(header_size);

    

    for ( auto next = props.begin(); next != props.end(); ++next ) {
      // only accept fields that size is within the allowed size
      if ( (next->size + field_header_size <= max_field_size) && (full_update||next->changed)) {
        props_size_queue.push(next);
        next->changed = false;
      }
    }
    size_t field_counts = 0;

    while ( !props_size_queue.empty() ) {
      PropertyData::Iterator next = props_size_queue.top();
      if ( buffer.size() + field_header_size + next->size <= max_packet_size ) {
        field_counts++;
        buffer.push_back((std::uint8_t)next->index);
        buffer.push_back((std::uint8_t)next->size );
        buffer.insert(buffer.end(), next->backing_data, next->backing_data + next->size);
        props_size_queue.pop();
      }
      else {
        send_update_data_message(buffer, field_counts, transport_quality);
        buffer.resize(header_size);
        field_counts = 0;
      }
    }
    if ( field_counts > 0 ) {
        send_update_data_message(buffer, field_counts, transport_quality);
        field_counts = 0;
    }   

  
  }

  void TinyDTP::on_message(const std::uint8_t *data, const size_t len) {
    using namespace internals;
    auto as_message = reinterpret_cast<const Message*>(data);
    switch ( as_message->msgty ) {
      case MessageType::Ping: {
        send_hello_message();
        on_ping();
        return;
      }
      case MessageType::Action: {
        const std::uint32_t action = as_message->content[0].action.action;
        const std::uint8_t* data = as_message->content[0].action.data;
        const size_t size = len - sizeof(Message) - sizeof(MessageAction);
        on_action(action, data, len);
        return;
      }
      default:
        return;
    }
  }

  void TinyDTP::send_hello_message() {
    using namespace internals;
    const auto size = sizeof(Message) + sizeof(MessageHello);
    std::uint8_t buf[size];
    std::memset(buf, 0, size);
    auto as_message = reinterpret_cast<Message *>(buf);
      
    std::memcpy(as_message->content->hello.uuid, uuid.data(), uuid.size());
    
    as_message->size = size;
    as_message->msgty = MessageType::Hello;
    
    
    transport->send_message(buf, size, TransportQuality::Reliable);
  }
  void TinyDTP::bind_transport(Transport *transport) {
    this->transport = transport;
    this->transport->bind_dtp(this);
  }

}