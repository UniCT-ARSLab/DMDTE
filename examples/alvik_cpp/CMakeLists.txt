cmake_minimum_required(VERSION 3.31)
project("alvik_simulator")

add_subdirectory(enet)

add_executable(
	alvik_simulator
	main.cpp
	tinyrpc/tinyrpc.cpp
)
set_property(TARGET alvik_simulator PROPERTY CXX_STANDARD 26)
target_include_directories(alvik_simulator PUBLIC enet/include )
target_link_libraries(alvik_simulator PRIVATE enet)