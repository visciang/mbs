cmake_minimum_required(VERSION 3.19)

project(c_native_binary)

link_libraries("-static")

set(DEPS_HEADERS_INCLUDE "-I ${CMAKE_SOURCE_DIR}/.deps/c_shared_library")
set(CMAKE_C_FLAGS "-g -O2 -Wall -Werror ${DEPS_HEADERS_INCLUDE}")

add_library(_c_shared_library STATIC IMPORTED)
set_property(TARGET _c_shared_library PROPERTY
             IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/.deps/c_shared_library/lib_c_shared_library.a")

add_library(_c_shared_sub_library STATIC IMPORTED)
set_property(TARGET _c_shared_sub_library PROPERTY
             IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/.deps/c_shared_sub_library/lib_c_shared_sub_library.a")

add_executable(c_native_binary main.c)
target_link_libraries(c_native_binary _c_shared_library _c_shared_sub_library)
