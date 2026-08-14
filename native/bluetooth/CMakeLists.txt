qt_add_qml_module(ateria_bluetooth
    SHARED
    URI Ateria.Bluetooth
    VERSION 1.0
    SOURCES
        bluetoothagent.cpp
        bluetoothagent.h
)

ateria_install_qml_module(ateria_bluetooth)

target_link_libraries(ateria_bluetooth
    PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Qml
)

target_compile_definitions(ateria_bluetooth
    PRIVATE
        QT_NO_CAST_FROM_ASCII
        QT_NO_CAST_TO_ASCII
)

target_compile_options(ateria_bluetooth PRIVATE -Wall -Wextra -Wpedantic)

if(ATERIA_BUILD_TESTS)
    add_subdirectory(tests)
endif()
