cmake_minimum_required(VERSION 3.10)

project(qamar VERSION 0.1)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_CXX_STANDARD_REQUIRED true)

configure_file(qamar_config.h.in qamar_config.h)

add_executable(qamar qamar.c)
target_include_directories (qamar PUBLIC "${PROJECT_BINARY_DIR}")

