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


project(qamar VERSION 0.1)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_CXX_STANDARD_REQUIRED true)

configure_file(qamar_config.h.in qamar_config.h)

FILE(GLOB_RECURSE sourcefiles src/*.c)
add_executable(qamar ${sourcefiles})
add_dependencies(qamar luajit)

target_include_directories (qamar PUBLIC "${PROJECT_BINARY_DIR}" "${install_dir}/include/luajit-2.1")
target_link_options (qamar PRIVATE -static-libgcc -static-libstdc++ -lm )
target_link_libraries(qamar luajit)

add_custom_command(
        TARGET qamar POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${CMAKE_SOURCE_DIR}/lua
                ${CMAKE_CURRENT_BINARY_DIR}/lua)
