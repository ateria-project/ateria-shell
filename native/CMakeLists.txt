cmake_minimum_required(VERSION 3.24)

project(ateria-native-modules VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Concurrent Core DBus Gui Network Qml)
find_package(PkgConfig REQUIRED)

qt_standard_project_setup(REQUIRES 6.6)

option(ATERIA_BUILD_TESTS "Build native module tests" OFF)
if(ATERIA_BUILD_TESTS)
    enable_testing()
    find_package(Qt6 6.6 REQUIRED COMPONENTS Test)
endif()

# Keep every generated QML module under one import root. The launcher adds this
# directory to QML_IMPORT_PATH before starting Quickshell.
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

add_subdirectory(network)
add_subdirectory(bluetooth)
add_subdirectory(wallpaper)
add_subdirectory(niri)
