cmake_minimum_required(VERSION 3.10)
include(ExternalProject)

ExternalProject_Add(luajit GIT_REPOSITORY https://luajit.org/git/luajit.git
    GIT_TAG           origin/v2.1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND "make"
    BUILD_IN_SOURCE true
    INSTALL_COMMAND ""
    )

project(qamar VERSION 0.1)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_CXX_STANDARD_REQUIRED true)

configure_file(qamar_config.h.in qamar_config.h)

add_executable(qamar qamar.c)
add_dependencies(qamar luajit)

target_include_directories (qamar PUBLIC "${PROJECT_BINARY_DIR}" "${PROJECT_BINARY_DIR}/luajit-prefix/src/luajit/src")
target_link_libraries(qamar PUBLIC "${PROJECT_BINARY_DIR}/luajit-prefix/src/luajit/src/libluajit.so")

