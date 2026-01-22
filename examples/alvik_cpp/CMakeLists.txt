cmake_minimum_required(VERSION 3.31)
project(simulator)

add_subdirectory(tinyrpc)

# add_executable(
# 	alvik_simulator
# 	main.cpp
# 	tinyrpc/tinyrpc.cpp
# )
# set_property(TARGET alvik_simulator PROPERTY CXX_STANDARD 26)
# target_include_directories(alvik_simulator PUBLIC enet/include )
# target_link_libraries(alvik_simulator PRIVATE enet)

add_executable(
	simulator
	main.cpp
)


target_include_directories(simulator PRIVATE tinyrpc/include )
target_link_libraries(simulator PRIVATE tinyrpc)