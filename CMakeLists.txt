cmake_minimum_required(VERSION 3.30)
project(god_complex C)

set(CMAKE_C_STANDARD 11)

find_package(glfw3 CONFIG REQUIRED)

add_subdirectory(god_complex)
add_subdirectory(gc_engine)
