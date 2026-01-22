
#include <cstdint>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <vector>

#define ARDUINOJSON_ENABLE_STD_STRING 1
#define ARDUINOJSON_ENABLE_ARDUINO_STRING 0
#include <ArduinoJson.h>

#pragma once

namespace tinyrpc {

template <typename T, typename = void>
struct has_not_equal : std::false_type {};

template <typename T>
struct has_not_equal<
    T, std::void_t<decltype(std::declval<T>() != std::declval<T>())>>
    : std::true_type {};

// 1. Helper interno: Scompatta la sequenza di indici
template <typename... Args, std::size_t... Is>
std::tuple<Args...> json_to_tuple_impl(JsonArray arr,
                                       std::index_sequence<Is...>) {
  // Espansione del pacchetto:
  // arr[0].as<Tipo0>(), arr[1].as<Tipo1>(), ...
  return std::make_tuple(
      arr[Is]
          .as<typename std::tuple_element<Is, std::tuple<Args...>>::type>()...);
}

// 2. Funzione Pubblica: Crea la sequenza di indici in base al numero di tipi
template <typename... Args> std::tuple<Args...> json_to_tuple(JsonArray arr) {
  // Controlla se la lunghezza dell'array corrisponde (opzionale ma consigliato)
  if (arr.size() != sizeof...(Args)) {
    // Gestisci l'errore o ritorna tupla vuota/default
    // Qui per semplicità ritorniamo una tupla default-constructed
    return std::tuple<Args...>();
  }

  // Genera la sequenza 0, 1, 2... N-1 e chiama l'helper
  return json_to_tuple_impl<Args...>(
      arr, std::make_index_sequence<sizeof...(Args)>{});
}

template <class T> class SchemaBuilder;
template <class T> class Schema;

enum class SerializationFormat { JSON, MessagePack };

template <class Context> struct AttrData {
  using AttrDataProcessUpdateFn = void (*)(const AttrData &, const Context &,
                                           void *, JsonArray, bool);
  using AttrDataProcessWriteBackFn = void (*)(const AttrData &, Context &,
                                              const JsonVariant);

  size_t index, offset, size;
  void *_raw_getter, *_raw_setter;
  AttrDataProcessUpdateFn updateFn;
  AttrDataProcessWriteBackFn writeBackFn;
  const char *name;
  mutable bool changed = false;
};
template <class Context> struct FuncData {
  using FuncDataWrapFn = void (*)(const FuncData &, Context &, JsonArray);
  size_t index, number_of_arguments;
  void *_raw_fn;
  FuncDataWrapFn wrapFn;
  const char *name;
};
template <class Context> struct Storage {
  std::vector<AttrData<Context>> attr_data;
  std::vector<uint8_t> attr_storage;
  std::vector<FuncData<Context>> func_data;
  std::vector<uint8_t> mesg_storage;
};

template <class Clazz> struct SchemaBuilder {
  using Self = SchemaBuilder;

  template <class T> using AttrGetterFn = T (*)(const Clazz &);
  template <class T> using AttrSetterFn = void (*)(Clazz &, const T &);
  template <class... Args> using FuncFn = void (*)(Clazz &, Args...);

  template <class T>
  Self &attr(const char *name, AttrGetterFn<T> getter = nullptr,
             AttrSetterFn<T> setter = nullptr) {
    constexpr auto alignment = sizeof(void *);
    constexpr auto size = sizeof(T);
    auto aligned_size = (size + alignment - 1) & ~(alignment - 1);

    if (storage) {

      auto updateFn = [](const AttrData<Clazz> &data, const Clazz &instance,
                         void *cache, JsonArray arr, bool force) {
        if (size != data.size)
          return;
        // cast back getterFn
        auto getterFn = reinterpret_cast<AttrGetterFn<T>>(data._raw_getter);

        // load current value and get a pointer to stored value
        T value = getterFn(instance);
        T *storedValue = reinterpret_cast<T *>(cache);

        // test if changed
        auto changed = false;
        if constexpr (has_not_equal<T>::value) { // use not_equal operator
                                                 // whenever possible
          changed = value != *storedValue;
        } else {
          changed = std::memcmp(&value, storedValue, size);
        }

        // write back
        *storedValue = value;
        if (changed || force) {
          auto tuple = arr.add<JsonArray>();
          tuple.add(data.index);
          tuple.add(value);
          // var.set<T>(value);
        }
      };
      auto writeBackFn = [](const AttrData<Clazz> &data, Clazz &instance,
                            const JsonVariant var) {
        if (size != data.size)
          return;
        // cast back getterFn
        auto setterFn = reinterpret_cast<AttrSetterFn<T>>(data._raw_setter);
        // copy the value from *in, may be unaligned!

        // set it!
        T value = var.as<T>();
        setterFn(instance, value);
      };

      auto data =
          AttrData<Clazz>{.index = number_of_attributes,
                          .offset = attr_data_size + aligned_size,
                          .size = size,
                          ._raw_getter = reinterpret_cast<void *>(getter),
                          ._raw_setter = reinterpret_cast<void *>(setter),
                          .updateFn = getter ? updateFn : nullptr,
                          .writeBackFn = setter ? writeBackFn : nullptr,
                          .name = name,
                          .changed = true};
      storage->attr_data.push_back(data);
    }
    number_of_attributes += 1;
    attr_data_size += aligned_size;
    return *this;
  }
  template <class... Args> Self &func(const char *name, FuncFn<Args...> fn) {
    if (storage) {
      constexpr size_t number_of_arguments = sizeof...(Args);

      auto wrapFn = [](const FuncData<Clazz> &data, Clazz &instance,
                       JsonArray args) {
        auto partial_arguments = json_to_tuple<Args...>(args);

        auto fn = reinterpret_cast<FuncFn<Args...>>(data._raw_fn);
        std::tuple<Clazz &, Args...> arguments = std::tuple_cat(
            std::tuple<Clazz &>(instance), std::move(partial_arguments));
        std::apply(fn, arguments);
      };
      auto data = FuncData<Clazz>{.index = number_of_functions,
                                  .number_of_arguments = number_of_arguments,
                                  ._raw_fn = reinterpret_cast<void *>(fn),
                                  .wrapFn = wrapFn,
                                  .name = name};
      storage->func_data.push_back(data);
    }
    number_of_functions += 1;
    return *this;
  }

  size_t number_of_attributes = 0;
  size_t attr_data_size = 0;
  size_t number_of_functions = 0;
  Storage<Clazz> *storage;
};

struct TransportEvent {
  enum Type {
    EventNone,
    EventConnected,
    EventDisconnected,
    EventMessage,
    EventError
  };
  Type type{EventNone};
  const uint8_t *data{nullptr};
  size_t data_size{0};
};

class Transport {
public:
  bool is_connected() const { return false; }
  void send_message(const uint8_t *data, size_t size, bool reliable = false) {}
  void service(std::function<void(const TransportEvent &)> eventFn) {}
};

struct JsonSerialization {

  static DeserializationError deserialize(JsonDocument &doc,
                                          const uint8_t *data, size_t len) {
    return deserializeJson(doc, reinterpret_cast<const char *>(data), len);
  }
  static size_t serialize(JsonDocument &doc, uint8_t *data, size_t len) {
    return serializeJson(doc, data, len);
  }
  static size_t measure(JsonDocument &doc) { return measureJson(doc); }
};
struct MsgPackSerialization {
  static DeserializationError deserialize(JsonDocument &doc, uint8_t *data,
                                          size_t len) {
    return deserializeMsgPack(doc, reinterpret_cast<const char *>(data), len);
  }
  static size_t serialize(JsonDocument &doc, uint8_t *data, size_t len) {
    return serializeMsgPack(doc, data, len);
  }
  static size_t measure(JsonDocument &doc) { return measureMsgPack(doc); }
};

template <class Context, class TransportImpl = Transport,
          class Serialization = JsonSerialization>
class Base {
public:
  using SchemaBuilderFn = void (*)(SchemaBuilder<Context> &);
  Base(SchemaBuilderFn schemaBuilderFn, const char *unique_id)
      : unique_id(unique_id) {
    setup_schema(schemaBuilderFn);
  }
  inline Context &as_ctx_ref() { return *as_ctx(); }
  inline Context *as_ctx() { return static_cast<Context *>(this); }

  inline TransportImpl &get_transport() { return transport; }

  template <class... Args> void call(const char *name, Args... args) {
    auto lock{std::lock_guard(resources_mutex)};
    auto message = jsonDocument.to<JsonArray>();
    message.add(MessageTypeCallNamed);
    message.add(name);
    auto args_array = message.add<JsonArray>();
    (args_array.add(args), ...);
    send_serialized();
  }
  void run_json_message(const char *json) {
    _on_message(reinterpret_cast<const uint8_t *>(json), strlen(json));
  }

  void process(bool force_update = false) {
    auto lock{std::lock_guard(resources_mutex)};
    process_attributes(force_update);
  }
  void service() {
    auto lock{std::lock_guard(resources_mutex)};
    transport.service([&](const auto &event) {
      switch (event.type) {
      case TransportEvent::EventConnected:
        _on_connect();
        break;
      case TransportEvent::EventDisconnected:
        _on_disconnect();
        break;
      case TransportEvent::EventMessage:
        _on_message(event.data, event.data_size);
        break;
      default:
        break;
      }
    });
  }

protected:
  virtual void on_connect() {}
  virtual void on_disconnect() {}

private:
  void _on_connect() {
    serve_hello();
    on_connect();
  }
  void _on_disconnect() { on_disconnect(); }
  void _on_message(const uint8_t *data, size_t size) {
    auto error = Serialization::deserialize(jsonDocument, data, size);
    if (error != DeserializationError::Ok)
      return;

    int message_type = jsonDocument[0].as<int>();
    switch (message_type) {
    case MessageTypeHello:
      serve_hello();
      break;
    case MessageTypeCall:
      serve_call();
      break;
    case MessageTypeCallNamed:
      serve_call_named();
      break;
    case MessageTypeUpdate:
      serve_update();
      break;
    default:
      break;
    }
  }
  void serve_hello() {
    auto reply = jsonDocument.to<JsonArray>();
    reply.add(MessageTypeHello);
    reply.add(unique_id);
    auto attrs = reply.add<JsonArray>();
    for (const auto &data : storage.attr_data) {
      auto attr_data = attrs.add<JsonArray>();
      attr_data.add<const char *>(data.name);
      attr_data.add<int>(static_cast<int>(data.index));
    }
    auto funcs = reply.add<JsonArray>();
    for (const auto &data : storage.func_data) {
      auto func_data = funcs.add<JsonArray>();
      func_data.add<const char *>(data.name);
      func_data.add<int>(static_cast<int>(data.index));
    }

    send_serialized();
  }
  void serve_call() {
    auto index = jsonDocument[1].as<size_t>();
    auto args = jsonDocument[2].as<JsonArray>();
    if (index < storage.func_data.size()) {
      auto func_data = storage.func_data.at(index);
      func_data.wrapFn(func_data, as_ctx_ref(), args);
    }
  }
  void serve_call_named() {
    auto name = jsonDocument[1].as<const char *>();
    auto args = jsonDocument[2].as<JsonArray>();
    for (size_t i = 0; i < storage.func_data.size(); ++i) {
      auto func_data = storage.func_data.at(i);
      if (std::strcmp(func_data.name, name) == 0) {
        func_data.wrapFn(func_data, as_ctx_ref(), args);
        return;
      }
    }
  }
  void serve_update() {
    auto attr_array = jsonDocument[1].as<JsonArray>();
    auto number_of_attributes = storage.attr_data.size();
    for (const auto &pair : attr_array) {
      auto index = pair[0].as<size_t>();
      if (index >= number_of_attributes)
        return;
      auto value = pair[0].as<JsonVariant>();
      auto attr_data = storage.attr_data.at(index);
      attr_data.writeBackFn(attr_data, as_ctx_ref(), value);
    }
  }

  void send_serialized() {
    size_t size = Serialization::measure(jsonDocument);
    storage.mesg_storage.resize(size, 0);

    auto ptr = storage.mesg_storage.data();
    Serialization::serialize(jsonDocument, ptr, size);
    transport.send_message(ptr, size);
  }

  void setup_schema(SchemaBuilderFn schemaBuilderFn) {
    setup_schema_dry(schemaBuilderFn);
    auto wet = SchemaBuilder<Context>();
    wet.storage = &storage;
    schemaBuilderFn(wet);
  }
  // runs a dry schemaBuilderFn so to setup storage
  // done thus far to minimize fragmentation
  void setup_schema_dry(SchemaBuilderFn schemaBuilderFn) {
    auto dry = SchemaBuilder<Context>();
    schemaBuilderFn(dry);
    storage.attr_data.reserve(dry.number_of_attributes);
    storage.attr_storage.resize(dry.attr_data_size, 0);

    storage.func_data.reserve(dry.number_of_functions);
  }

  void process_attributes(bool force_update) {
    auto root = jsonDocument.template to<JsonArray>();
    root.add<int>(MessageTypeUpdate);
    auto array = jsonDocument.template add<JsonArray>();
    for (size_t i = 0; i < storage.attr_data.size(); ++i) {
      auto attr_data = storage.attr_data.at(i);
      if (attr_data.updateFn) {
        auto attr_storage = storage.attr_data.data() + attr_data.offset;
        attr_data.updateFn(attr_data, as_ctx_ref(),
                           reinterpret_cast<void *>(attr_storage), array,
                           force_update);
      }
    }

    if (array.size() > 0) {
      send_serialized();
    }
  }
  enum MessageType {
    MessageTypeHello = 0,
    MessageTypeCall,
    MessageTypeCallNamed,
    MessageTypeUpdate
  };
  // is this enough to make this lasagna thread safe???
  std::recursive_mutex resources_mutex;
  JsonDocument jsonDocument;
  Storage<Context> storage;
  TransportImpl transport;

  const char *unique_id;
};

} // namespace tinyrpc