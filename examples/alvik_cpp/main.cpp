
#include <optional>
#include <iostream>
#include <cstring>
#include <string_view>
#include <memory>
#include <functional>
#include <vector>
#include <cstdint>
#include <deque>

#include <tinyrpc/tinyrpc.h>

struct Pose {
    float x, y, theta;
};
using namespace tinyrpc;
namespace ARDUINOJSON_NAMESPACE {
template <>
struct Converter<Pose> {
  static bool toJson(const Pose& src, JsonVariant dst) {
    auto array = dst.to<JsonArray>();
    dst.add(src.x);
    dst.add(src.y);
    dst.add(src.theta);
    return true;
  }

  static Pose fromJson(JsonVariantConst src) {
    return Pose{ src[0], src[1], src[2]};
  }

  static bool checkJson(JsonVariantConst src) {
    return src[0].is<float>() && src[1].is<float>() && src[2].is<float>();
  }
};
}



struct MyContext : public Base<MyContext> {
    int counter = 0;
    Pose pose{.0f,.0f,.0f};
    MyContext(Base::SchemaBuilderFn fn, const char* unique_id): Base(fn, unique_id) {}
    int increment() {
        return counter++;
    };
};



int main ( int argc, const char **argv ) {

    auto buildSchema = [](SchemaBuilder<MyContext>& builder){
			builder
				.attr<int>("counter", [](const auto& ctx) {return ctx.counter;})
				.attr<Pose>("pose", [](const auto& ctx) { return ctx.pose;})
				.func("increment", +[](MyContext& ctx, int count) { 
                    ctx.counter += count;
                });
	};

	auto context = MyContext(buildSchema, "unique_name(chi legge è gay)");
    context.process(true);
    context.service();
    return 0;
}