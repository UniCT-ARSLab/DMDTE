#include <cstddef>
#include <cstring>
#include <memory>
#include <string_view>
#include <unordered_map>
#include <vector>
#pragma once
namespace tinyrpc {

    using u8 = unsigned char;
    using i8 = signed char;
    using u16 = unsigned short;
    using i16 = signed short;
    using u32 = unsigned int;
    using i32 = signed int;
    using u64 = unsigned long long;
    using i64 = signed long long;
    using usize = std::size_t;
    using f32 = float;
    using f64 = double;
    struct vec2f { f32 x,y; };
    struct vec3f { f32 x,y,z; };
    struct vec2i { i32 x,y; };
    struct vec3i { i32 x,y,z; };
    /*enum class PropertyType {
        UNKNOWN,
        U8,
        I8,
        U16,
        I16,
        U32,
        I32,
        U64,
        I64,
        F32,
        F64,
        VEC2F,
        VEC3F,
        VEC2I,
        VEC3I
    };*/

    class ClientAbstraction {
    public:
        ClientAbstraction();
        ~ClientAbstraction();

        bool begin(std::string_view hostname, u16 port);

        bool is_connected() const;

        virtual void on_connect() {};
        virtual void on_disconnect() {};
        virtual void on_message(const u8* data, u32 data_size) {};
        virtual int generate_unique_id() const;
        void send_message(const u8* data, u32 size, bool reliable = false);

        void service();

    private:
        struct Impl;
        std::unique_ptr<Impl> impl;
    };

    template < class Context >
    class BaseRAI : protected ClientAbstraction {
    private:
        struct Property {
            using ReadIntoFn = void(*)(Context&, const Property &ppd, void *dst, int size);
            using WriteFromFn = void(*)(Context&, Property &ppd, const void *src, int size);
            std::string_view name;
            u32 index;
            u32 size;
            u32 offset;
            void *getter, *setter;
            ReadIntoFn readFn;
            WriteFromFn writeFn;
        };
        struct Method {
            using HandlerFn = void(*)(Context&, const void *input, int size);
            std::string_view name;
            u32 index;
            HandlerFn handler;
        };

    public:
        template < class T >
        struct PropertyDescriptor {
            using Getter = T(*)(Context&);
            using Setter = void(*)(Context&, const T& value);
            std::string_view name;
            Getter getter{nullptr};
            Setter setter{nullptr};
        };
        struct MethodDescriptor {
            using HandlerFn = void(*)(Context&, const void *input, int size);
            std::string_view name;
            HandlerFn handler;
        };
        

        bool begin(std::string_view hostname, u16 port) {
            return ClientAbstraction::begin(hostname, port);
        }

        void export_method(MethodDescriptor desc) {
            auto method = Method {
                .name = desc.name,
                .index = methods.size(),
                .handler = desc.handler
            };
            this->methods.push_back(method);
        }
        template < class T >
        void export_property(PropertyDescriptor<T> desc) {
            auto prop = Property {
                .name = desc.name,
                .index = this->properties.size(),
                .size = sizeof(T),
                .offset = 0,
                .getter = reinterpret_cast<void*>(desc.getter),
                .setter = reinterpret_cast<void*>(desc.setter),
                .readFn = nullptr,
                .writeFn = nullptr
            };
            if ( prop.getter != nullptr ) {
                prop.offset = property_storage.size();
                property_storage.resize(prop.offset + prop.size);
                prop.readFn = [](Context& self, const Property &ppd, void *dst, int size) {
                    if ( ppd.size != size ) return;
                    auto getter = reinterpret_cast<typename PropertyDescriptor<T>::Getter>(ppd.getter);
                    T val = getter(self);
                    std::memcpy(dst, &val, size);
                };
            }
            if ( prop.setter != nullptr ) {
                prop.writeFn = [](Context& self, Property &ppd, const void *src, int size) {
                    if ( ppd.size != size ) return;
                    auto setter = reinterpret_cast<typename  PropertyDescriptor<T>::Setter>(ppd.setter);
                    T aligned;
                    std::memcpy(&aligned, src, size);
                    setter(self, aligned);
                };
            }
            this->properties.push_back(prop);
        }

        void call(u32 method_index, const u8 *args, u32 arg_size) {
            u32 msgsize = sizeof(u32) + arg_size;
            u8 message[msgsize];
            memset(message, 0, msgsize);
            message[0] = static_cast<u8>(MessageType::Call);
            message[1] = static_cast<u8>(method_index);
            *((u16*) message + 1) = arg_size;
            *((u16*)message + 1) = arg_size;
            std::memcpy(message + 4, args, arg_size);
            this->send_message(message, msgsize, true);
        }
        void update(bool full_and_reliable = false ) {
            update_storage.clear();
            // reserve first two bytes
            write_to(update_storage, nullptr, sizeof(u8)*2);
            u32 written_properties = 0;
            for ( const auto &prop : properties ) {
                if ( prop.readFn != nullptr ) {
                    /// todo!: use diffs
                    written_properties += write_property_if_changed(prop, full_and_reliable);
                }
            }
            if ( written_properties > 0 && this->is_connected() ) {
                update_storage[0] = static_cast<u8>(MessageType::Update);
                update_storage[1] = static_cast<u8>(written_properties);
                ClientAbstraction::send_message(update_storage.data(), update_storage.size(), full_and_reliable);
            }
        }

        void service(bool full_update = false) { 
            ClientAbstraction::service();
            update( full_update );
        }

        void set_agent_identification(std::string_view agent_identification) {
            this->agent_identification = agent_identification;
        }
    protected:
        Context* ctx() {
            return static_cast<Context*>(this);
        }
        Context& ctx_ref() {
            return *static_cast<Context*>(this);
        }
        void on_message(const u8* data, u32 data_size) override {

            MessageType msgtype = static_cast<MessageType>(*(u8*)data);

            switch (msgtype) {
                case MessageType::Call:
                    return on_call(data, data_size);
                case MessageType::Update:
                    return on_update(data, data_size);
            }
        };
        void on_connect() override {
            send_agent_identification();
        }
    private:
        void send_agent_identification() {
            u32 msgsize = sizeof(u8) + agent_identification.size();
            u8 message[msgsize];
            memset(message, 0, msgsize);
            message[0] = static_cast<u8>(MessageType::Identify);
            
            std::memcpy(message + 1, agent_identification.data(), agent_identification.size());
            this->send_message(message, msgsize, true);
        }
        void on_call(const u8 *data, u32 data_size) {
            u32 method_index = (u32)data[1];
            u32 arg_size = *((u16*) data + 1);
            const u8* fwd_args = ((u8*)data + 4);
            if ( method_index < methods.size() ) {
                methods[method_index].handler(ctx_ref(), fwd_args, arg_size);
            }

        }
        void on_update(const u8 *data, u32 data_size) {
            int num_properties = int(data[1]);
            const u8 *it = data + 2;

            for ( int i = 0; i < num_properties; ++i ) {
                int index = int(*it++); 
                int size = int(*it++);
                if ( index < properties.size() ) {
                    auto &prop = properties.at(index);
                    if ( prop.writeFn ) {
                        prop.writeFn(ctx_ref(), prop, static_cast<const void*>(it), size );
                    }
                }
                it += size;
            }
            return;
            /*u32 num_properties = (u32)data[1];
            const u8 *it = data + 2;
            for ( u32 i = 0; i < num_properties; ++i) {
                u32 index = (u32)(*it++);
                if ( index < properties.size() ) {
                    auto &property = properties[index];
                    if ( property.has_setter() ) {
                        property.set(ctx_ref(), it, data_size);
                    }
                }
                it+=data_size;
            }*/
        }
        u32 write_property_if_changed(const Property &prop, bool force = false) {
            std::uint8_t temp[prop.size];
            std::uint8_t *storage = property_storage.data() + prop.offset;
            
            prop.readFn(ctx_ref(), prop, temp, prop.size);
            
            bool differs = std::memcmp(temp, storage, prop.size);
            
            if ( force || differs ) {

                std::memcpy(storage, temp, prop.size);
                u8 index = (u8)prop.index;
                u8 size = (u8)prop.size;
                write_to(update_storage, &index, sizeof(u8));
                write_to(update_storage, &size, sizeof(u8));
                write_to(update_storage, temp, prop.size);
                return 1;
            }
            return 0;

        }
        u32 write_property(const Property &prop) {
            u8 index = (u8)prop.index;
            u8 size = (u8)prop.size;

            write_to(update_storage, &index, sizeof(u8));
            write_to(update_storage, &size, sizeof(u8));
            // allocates prop.size memory onto update_storage
            usize anchor = write_to(update_storage, nullptr, prop.size );
            auto ptr = update_storage.data() + anchor;
            prop.readFn(ctx_ref(), prop, ptr, prop.size);

            return prop.size;
        }

        static usize write_to(std::vector<u8> &vec, const u8* data, usize size ) {
            auto offset = vec.size();
            vec.resize(vec.size() + size);
            if ( data != nullptr ) {
                std::memcpy(vec.data() + offset, data, size);
            }
            return offset;
        }


        
    protected:
        std::string_view agent_identification = "BaseRAI";
        enum class MessageType: u8 {
            Call = 0, Update = 1, Identify = 2
        };
        // std::unordered_map<std::string_view, usize> property_name_to_index{};
        std::vector<Property> properties;

        // std::unordered_map<std::string_view, usize> method_name_to_index{};
        std::vector<Method> methods;

        // todo: implement diffs using property storages
        std::vector<u8> property_storage;
        std::vector<u8> update_storage;
        // Callback on_update_cb;


    };

}
