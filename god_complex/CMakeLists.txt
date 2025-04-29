file(GLOB_RECURSE GAME_SRCS CONFIGURE_DEPENDS src/*.c)
file(GLOB_RECURSE GAME_HEADERS CONFIGURE_DEPENDS src/*.h)
add_executable(god_complex ${GAME_SRCS} ${GAME_HEADERS})

target_include_directories(god_complex PRIVATE ${CMAKE_SOURCE_DIR}/gc_engine/include)

target_link_libraries(god_complex PRIVATE gc_engine)
