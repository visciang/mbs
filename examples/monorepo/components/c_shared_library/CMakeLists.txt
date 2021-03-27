cmake_minimum_required(VERSION 3.19)

project(c_shared_library)

set(DEPS_HEADERS_INCLUDE "-I ${CMAKE_SOURCE_DIR}/.deps/c_shared_sub_library")
set(CMAKE_C_FLAGS "-g -O2 -Wall -Werror ${DEPS_HEADERS_INCLUDE}")

add_library(_c_shared_library STATIC lib.c)