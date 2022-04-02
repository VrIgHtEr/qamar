cmake_minimum_required(VERSION 3.10)
include(ExternalProject)

ExternalProject_Add(project_luajit
    GIT_REPOSITORY "https://luajit.org/git/luajit.git"
    GIT_TAG "origin/v2.1"
  PREFIX ${CMAKE_CURRENT_BINARY_DIR}/luajit-2.1
  CONFIGURE_COMMAND ""
  BUILD_IN_SOURCE true
  BUILD_COMMAND make
  INSTALL_COMMAND make install
  PREFIX=${CMAKE_CURRENT_BINARY_DIR}/luajit-2.1
)
ExternalProject_Get_Property(project_luajit install_dir)
add_library(luajit STATIC IMPORTED)
set_property(TARGET luajit PROPERTY IMPORTED_LOCATION ${install_dir}/lib/libluajit-5.1.a)
add_dependencies(luajit project_luajit)

##############################################################

set(LIBUV_DEPS_DIR ${CMAKE_SOURCE_DIR}/deps/libuv)
ExternalProject_Add(
    libuv
    GIT_REPOSITORY https://github.com/libuv/libuv.git
    GIT_TAG v1.44.1
    DOWNLOAD_DIR ${LIBUV_DEPS_DIR}
    TMP_DIR ${LIBUV_DEPS_DIR}/tmp
    STAMP_DIR ${LIBUV_DEPS_DIR}/stamp
    SOURCE_DIR ${LIBUV_DEPS_DIR}/src
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND ./autogen.sh && ./configure
    BUILD_COMMAND make -j4
    INSTALL_COMMAND ""
    TEST_COMMAND ""
)
include_directories(${LIBUV_DEPS_DIR}/src/include)
find_library(LIBUV_STATIC_LIBRARY NAMES libuv.a libuv PATHS ${LIBUV_DEPS_DIR}/src PATH_SUFFIXES .libs Release NO_DEFAULT_PATH)
find_library(LIBUV_SHARED_LIBRARY NAMES uv libuv PATHS ${LIBUV_DEPS_DIR}/src PATH_SUFFIXES .libs Release NO_DEFAULT_PATH)

##############################################################
project(qamar VERSION 0.1)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_CXX_STANDARD_REQUIRED true)

configure_file(qamar_config.h.in qamar_config.h)

FILE(GLOB_RECURSE sourcefiles src/*.c)
add_executable(qamar ${sourcefiles})
add_dependencies(qamar luajit libuv)

##############################################################
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
##############################################################

target_include_directories (qamar PUBLIC "${PROJECT_BINARY_DIR}" "${install_dir}/include/luajit-2.1")
target_link_options (qamar PRIVATE -static-libgcc -static-libstdc++ -lm )
target_link_libraries(qamar luajit 
    Threads::Threads 
    ${LIBUV_STATIC_LIBRARY})

add_custom_command(
        TARGET qamar POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${CMAKE_SOURCE_DIR}/lua
                ${CMAKE_CURRENT_BINARY_DIR}/lua)
