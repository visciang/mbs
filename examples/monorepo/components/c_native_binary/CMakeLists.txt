cmake_minimum_required(VERSION 3.19)

project(c_native_binary)

set(DEPS_HEADERS_INCLUDE "-I $ENV{MBS_DIR_C_SHARED_LIBRARY}")
set(CMAKE_C_FLAGS "-g -O2 -Wall -Werror ${DEPS_HEADERS_INCLUDE}")

add_library(_c_shared_library SHARED IMPORTED)
set_property(TARGET _c_shared_library PROPERTY
             IMPORTED_LOCATION "$ENV{MBS_DIR_C_SHARED_LIBRARY}/lib_c_shared_library.so")

add_executable(c_native_binary main.c)
target_link_libraries(c_native_binary _c_shared_library)
