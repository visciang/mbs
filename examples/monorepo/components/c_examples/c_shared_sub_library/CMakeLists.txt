cmake_minimum_required(VERSION 3.19)

project(c_shared_sub_library)

set(CMAKE_C_FLAGS "-g -O2 -Wall -Werror")

add_library(_c_shared_sub_library STATIC sub_lib.c)