#include <cstddef>
#include <cstring>
#include <functional>
#include <memory>
#include <queue>
#include <string_view>
#include <unordered_map>
#include <vector>
#include <mutex>
#include <algorithm>
#pragma once
namespace tinydtp {

namespace utils {
  constexpr std::array<std::uint8_t, 16> uuid_to_bytes(std::string_view uuid) {
    std::array<std::uint8_t, 16> result;
    
    auto result_it = result.begin();
    for ( auto it = uuid.begin(); it != uuid.end();) {
      std::string hex_str;
      if (*it == '-') it++;
      hex_str.push_back(*it++);
      if (*it == '-') it++;
      hex_str.push_back(*it++);
      (*result_it++) = stoi(hex_str, nullptr, 16);
    }
    return result;
  };
}

namespace internals {
template <class T>
inline std::uint8_t *as_bytes(T *data) {
  return reinterpret_cast<std::uint8_t *>(data);
};
template <class T>
inline const std::uint8_t *as_bytes(const T *data) {
  return reinterpret_cast<const std::uint8_t *>(data);
};
enum class MessageType : std::uint8_t { Ping = 0, Hello, Data, Action };

#pragma pack(push, 1)
struct MessagePing {};
struct MessageHello {
  std::uint8_t uuid[16];
};
struct MessageData {
  std::uint8_t count;

  struct FieldData {
    std::uint8_t index;
    std::uint8_t size;
    std::uint8_t data[];
  };

  std::uint8_t data[];
};
struct MessageAction {
  std::uint32_t action;
  std::uint8_t data[];
};
struct Message {
  std::uint16_t size;
  MessageType msgty;
  union {
    MessagePing ping;
    MessageHello hello;
    MessageData data;
    MessageAction action;
  } content[];
};
// static_assert(sizeof(Message) == sizeof(MessageType));

#pragma pack(pop)
} // namespace internals

class TinyDTP;

enum class TransportQuality { None = 0, Sequenced = 1 << 0, Reliable = 1 << 1 };

inline TransportQuality operator|(TransportQuality a, TransportQuality b)
{
    return static_cast<TransportQuality>(static_cast<int>(a) | static_cast<int>(b));
}
inline TransportQuality operator&(TransportQuality a, TransportQuality b)
{
    return static_cast<TransportQuality>(static_cast<int>(a) & static_cast<int>(b));
}


class Transport {
public:
  virtual size_t get_maximum_packet_size() const { return 1024; };
  virtual size_t send_message(const std::uint8_t *pkt, const size_t size, TransportQuality transport_quality = TransportQuality::None ) = 0;
  // virtual size_t recv(const std::uint8_t **pkt) { *pkt = nullptr; return 0; };
  virtual size_t service() = 0;

  virtual bool is_connected() const { return true; }

  void bind_dtp(TinyDTP *tinydtp);

protected:
    void on_connection_state_change(bool connected);
    void on_message(const std::uint8_t *data, size_t len);
private:
    TinyDTP *tinydtp;
};

class TinyDTP {
public:
  using UUID=std::array<std::uint8_t,16>;
  /** Strategy to be used to signal property changes to the other DTP end. */
  enum class SignalStrategy {
    // Do not signal
    None,
    // Just signal
    Always,
    // Signal only on change
    OnChange
  };
  template <class T> struct Property {
    size_t index;
  };

  TinyDTP() {}
  ~TinyDTP() { dispose_backing_data(); }

  /**
   * Creates a property.
   *
   * @param name the name of the property
   * @return an opaque reference to the property
   */
  template <class T> Property<T> create_property(std::string_view name = "") {
    auto index = this->props.size();
    this->props.push_back(
        {.index = index, .name = name, .size = sizeof(T), .changed = false});

    return {index};
  }

  /**
   * Finalizes all the properties recorded thus far, creates backing data.
   *
   * @return a non zero value if allocation for backing data failed
   */
  int finalize(Transport *transport);

  /**
   * Sets a property value, using given strategy for signaling changes to the
   * DTP end ( by default on change )
   *
   * @param prop the property reference
   * @param value the property value
   * @param strategy the strategy to be used to signal to DTP end
   */
  template <class T>
  void set_property(Property<T> prop, const T &value,
                    SignalStrategy strategy = SignalStrategy::OnChange) {

    std::lock_guard lock(properties_lock);
    auto value_ptr = reinterpret_cast<const std::uint8_t *>(&value);
    auto &pdata = this->props.at(prop.index);
    switch (strategy) {
    case SignalStrategy::None: {
      std::memcpy(pdata.backing_data, value_ptr, sizeof(T));
      return;
    }
    case SignalStrategy::Always: {
      std::memcpy(pdata.backing_data, value_ptr, sizeof(T));
      pdata.changed = true;
      return;
    }
    case SignalStrategy::OnChange: {
      bool changed = pdata.changed =
          std::memcmp(pdata.backing_data, value_ptr, sizeof(T));
      if (changed) {
        std::memcpy(pdata.backing_data, value_ptr, sizeof(T));
      }
      return;
    }
    }
  }

  /**
   * Reads a given property.
   *
   * @param prop the property reference
   * @return the value of the property
   */
  template <class T> T get_property(Property<T> prop) {
    std::lock_guard lock(properties_lock);
    const auto &pdata = this->props.at(prop.index);
    T retval{};
    std::memcpy(reinterpret_cast<std::uint8_t *>(&retval), pdata.backing_data,
                sizeof(T));

    return retval;
  }

  /**
   * Handles dispatched actions by the other DTP end.
   *
   * @param action the action number
   * @param data the data pointer
   * @param data_len the length of the data
   */
  virtual void on_action(std::uint32_t action, const std::uint8_t *data,
                         const size_t data_len) {

    
  }



  /**
   * Called whenever the connection state changes
   *
   * @param connected the state of the connection
   */
  virtual void on_connection_state_change(bool connected) {}
  /**
   * Called after a ping message is received, but after a hello message is sent
   *
   * @param connected the state of the connection
   */
  virtual void on_ping() {}
  /**
   * Dispatches one action to the other DTP end.
   *
   * @param action the action number
   * @param data the data pointer
   * @param data_len the length of the data
   */
  void dispatch(std::uint32_t action, const std::uint8_t *data,
                const size_t data_len);

  /** Runs logic
   * @param full_update sends full state update to DTP end
   */
  void service(bool full_update = false);

  UUID get_uuid( ) const {
    return uuid;
  }
  void set_uuid(UUID uuid ) {
    this->uuid = uuid;
  }

  struct PropertyData {
    struct ComparePropertyData {
      bool operator()(std::vector<PropertyData>::iterator a,
                      std::vector<PropertyData>::iterator b) {
        return a->size < b->size;
      }
    };
    using Container = std::vector<PropertyData>;
    using Iterator = Container::iterator;
    using SizePriorityQueue =
        std::priority_queue<Iterator, std::vector<Iterator>,
                            ComparePropertyData>;

    size_t index;
    std::string_view name;
    size_t size;
    mutable bool changed;
    std::uint8_t *backing_data{nullptr};
  };
  const std::vector<PropertyData> &get_properties() const { return props; }
  
  protected:
  void send_update_data(bool full_update);
  void send_hello_message();
  
  private:
  void bind_transport(Transport *transport);
  friend class Transport;
  void dispose_backing_data();
  size_t compute_backing_data_size();
  void assign_backing_data_storate_pointers_to_properties();
  void send_update_data_message(std::vector<uint8_t> &data, size_t fields_count, TransportQuality transport_quality);

  /**
   * Sends update data to the other DTP end, takes into account the transport's limit packet size!
   */

  void on_message(const std::uint8_t *data, const size_t len);


  Transport *transport;

  PropertyData::Container props;
  PropertyData::SizePriorityQueue props_size_queue;
  std::vector<std::uint8_t> message_buffer;
  std::vector<std::uint8_t> action_buffer;
  std::uint8_t *backing_data{nullptr};

  UUID uuid;

  std::mutex properties_lock;
  std::mutex message_buffer_lock;
  std::mutex action_buffer_loc;
};

} // namespace tinydtp
