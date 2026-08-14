pkg_check_modules(LIBNM REQUIRED IMPORTED_TARGET libnm>=1.26)

qt_add_qml_module(ateria_network
    SHARED
    URI Ateria.Network
    VERSION 1.0
    SOURCES
        wifimanager.cpp
        wifimanager.h
        wifinetworkmodel.cpp
        wifinetworkmodel.h
)

target_link_libraries(ateria_network
    PRIVATE
        Qt6::Core
        Qt6::Qml
        PkgConfig::LIBNM
)

target_compile_definitions(ateria_network
    PRIVATE
        QT_NO_CAST_FROM_ASCII
        QT_NO_CAST_TO_ASCII
)

target_compile_options(ateria_network PRIVATE -Wall -Wextra -Wpedantic)
