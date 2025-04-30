file(GLOB_RECURSE ENGINE_SRCS CONFIGURE_DEPENDS src/*.c)
file(GLOB_RECURSE ENGINE_HEADERS CONFIGURE_DEPENDS include/*.h)
add_library(gc_engine STATIC
  ${ENGINE_SRCS}
  ${ENGINE_HEADERS}
  ${CMAKE_SOURCE_DIR}/code/external/glad/src/glad.c
  ${CMAKE_SOURCE_DIR}/code/external/stb/src/stb.c
)

target_include_directories(gc_engine PUBLIC
  include
  ${CMAKE_SOURCE_DIR}/code/external/stb/include
  ${CMAKE_SOURCE_DIR}/code/external/glad/include
)

target_link_libraries(gc_engine PUBLIC glfw opengl32)

target_compile_definitions(gc_engine PUBLIC GLFW_INCLUDE_NONE)
